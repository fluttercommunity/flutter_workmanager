// Copyright 2026 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// Flutter-free execution registry and headless runner for Windows.
///
/// Mirrors `package:workmanager_web/execution.dart`: the callback dispatcher
/// registers its handler with [WorkmanagerExecution], and the headless
/// process started by Task Scheduler (`<app.exe> --background-task <name>`)
/// invokes that handler, logs the result and exits.
library;

import 'dart:convert';
import 'dart:io';

/// Signature of the handler invoked when a background task runs.
///
/// [taskName] is the value passed when registering the task; [inputData] is
/// the registered input data (int, bool, double, String and their
/// lists/maps — everything JSON-encodable).
typedef BackgroundTaskHandler = Future<bool> Function(
  String taskName,
  Map<String, dynamic>? inputData,
);

/// Shared registry that holds the currently registered background task
/// handler.
///
/// One instance is shared by the foreground app and the headless processes
/// Task Scheduler starts, so dispatcher code stays identical everywhere.
class WorkmanagerExecution {
  WorkmanagerExecution._();

  /// The process-wide singleton.
  static final WorkmanagerExecution instance = WorkmanagerExecution._();

  /// The handler registered by the most recent [executeTask] call.
  BackgroundTaskHandler? taskHandler;

  /// The callback dispatcher passed to `WorkmanagerWindows().initialize(...)`.
  ///
  /// Kept so the foreground app can re-run the dispatcher when needed.
  Function? callbackDispatcher;

  /// Registers [handler] as the background task handler (mirrors
  /// `Workmanager().executeTask(...)`).
  void executeTask(BackgroundTaskHandler handler) {
    taskHandler = handler;
  }

  /// Runs the registered handler with [taskName] and [inputData].
  ///
  /// Returns `false` when no handler has been registered yet.
  Future<bool> runTask(String taskName, Map<String, dynamic>? inputData) {
    final handler = taskHandler;
    if (handler == null) {
      return Future<bool>.value(false);
    }
    return handler(taskName, inputData);
  }
}

/// Returns the task name passed on the command line via
/// `--background-task <taskName>`, or `null` when [args] do not describe a
/// background-task invocation.
String? backgroundTaskNameFromArgs(List<String> args) {
  final index = args.indexOf('--background-task');
  if (index < 0 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1];
}

/// Returns the payload file path passed via `--payload-file <path>`, or
/// `null` when absent.
String? payloadFilePathFromArgs(List<String> args) {
  final index = args.indexOf('--payload-file');
  if (index < 0 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1];
}

/// Runs one background task to completion and returns the process exit code
/// Task Scheduler records as the task's last result:
///
/// * `0` — the handler ran and returned `true`.
/// * `1` — the handler returned `false`, threw, or no handler was registered.
///
/// [callbackDispatcher] is invoked first so it can register its handler (see
/// [WorkmanagerExecution]); [payloadFilePath] is the JSON payload written at
/// registration time, or `null` when the task was registered without
/// `inputData`.
Future<int> runBackgroundTask(
  String taskName, {
  required String? payloadFilePath,
  required Function callbackDispatcher,
}) async {
  try {
    final inputData = await readPayloadFile(payloadFilePath);
    callbackDispatcher();
    final handler = WorkmanagerExecution.instance.taskHandler;
    if (handler == null) {
      stderr.writeln(
        'workmanager_windows: no background task handler was registered for '
        '"$taskName". On Windows the callbackDispatcher must register the '
        'handler with WorkmanagerWindows().executeTask(...) (or '
        'WorkmanagerExecution.instance.executeTask(...)).',
      );
      return 1;
    }
    final result = await handler(taskName, inputData);
    stdout.writeln(
      'workmanager_windows: background task "$taskName" finished '
      '(result: $result).',
    );
    return result ? 0 : 1;
  } catch (error, stackTrace) {
    stderr.writeln(
      'workmanager_windows: background task "$taskName" failed: $error',
    );
    stderr.writeln(stackTrace);
    return 1;
  }
}

/// Reads and JSON-decodes the payload file at [path].
///
/// Returns `null` when [path] is `null`, the file does not exist, or its
/// content is not a JSON object.
Future<Map<String, dynamic>?> readPayloadFile(String? path) async {
  if (path == null) {
    return null;
  }
  final file = File(path);
  if (!await file.exists()) {
    return null;
  }
  final decoded = jsonDecode(await file.readAsString());
  return decoded is Map<String, dynamic> ? decoded : null;
}
