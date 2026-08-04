// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

import '../execution.dart';
import 'payload_store.dart';

/// A parsed `--background-task` invocation from the process arguments.
///
/// A systemd unit launches the app with `--background-task <taskName>` (and
/// optionally `--payload <path>` pointing at the JSON payload written at
/// registration time); the app's `main()` hands its arguments to
/// [WorkmanagerLinux.maybeRunBackgroundTask], which detects and runs the
/// invocation.
class BackgroundTaskInvocation {
  /// Creates an invocation.
  const BackgroundTaskInvocation({required this.taskName, this.payloadPath});

  /// The task name passed to the background task handler.
  final String taskName;

  /// Path of the JSON payload file, when one was passed.
  final String? payloadPath;

  /// Parses [args] for a `--background-task` invocation.
  ///
  /// Returns `null` when [args] do not contain `--background-task` followed
  /// by a task name (the app should start normally).
  static BackgroundTaskInvocation? tryParse(List<String> args) {
    final index = args.indexOf('--background-task');
    if (index < 0 || index + 1 >= args.length) {
      return null;
    }
    final taskName = args[index + 1];
    String? payloadPath;
    final payloadIndex = args.indexOf('--payload');
    if (payloadIndex >= 0 && payloadIndex + 1 < args.length) {
      payloadPath = args[payloadIndex + 1];
    }
    return BackgroundTaskInvocation(
      taskName: taskName,
      payloadPath: payloadPath,
    );
  }
}

/// Executes a background invocation in the headless process.
///
/// The flow mirrors the interactive app: the [BackgroundTaskInvocation] is
/// loaded, the callback dispatcher runs so it can register its handler with
/// [WorkmanagerExecution.executeTask], the handler is invoked with the
/// payload, and the result is reported.
class BackgroundTaskRunner {
  /// Creates a runner.
  ///
  /// [payloadDirectory] roots the [PayloadStore] used to load payloads; it
  /// only matters when a relative `--payload` path is passed.
  BackgroundTaskRunner({String? payloadDirectory})
      : _payloadStore = PayloadStore(
          Directory(payloadDirectory ?? Directory.systemTemp.path),
        );

  final PayloadStore _payloadStore;

  /// Runs [invocation].
  ///
  /// Returns `true` when the registered handler reported success, `false`
  /// when the handler failed, threw, or was never registered (no handler
  /// called [WorkmanagerExecution.executeTask]).
  Future<bool> run(
    BackgroundTaskInvocation invocation,
    Function callbackDispatcher,
  ) async {
    final inputData = invocation.payloadPath == null
        ? null
        : await _payloadStore.load(invocation.payloadPath!);
    try {
      callbackDispatcher();
    } on Object catch (error, stackTrace) {
      stderr.writeln(
        'workmanager_linux: callback dispatcher threw for task '
        '"${invocation.taskName}": $error\n$stackTrace',
      );
      return false;
    }
    final started = DateTime.now();
    final taskInfo = TaskDebugInfo(
      taskName: invocation.taskName,
      inputData: inputData,
      startTime: started,
    );
    WorkmanagerDebug.reportStatus(taskInfo, TaskStatus.started, null);
    try {
      final success = await WorkmanagerExecution.instance.runTask(
        invocation.taskName,
        inputData,
      );
      WorkmanagerDebug.reportStatus(
        taskInfo,
        success ? TaskStatus.completed : TaskStatus.failed,
        TaskResult(
          success: success,
          duration: DateTime.now().difference(started),
          error: success ? null : 'handler returned false',
        ),
      );
      return success;
    } on Object catch (error, stackTrace) {
      stderr.writeln(
        'workmanager_linux: background task "${invocation.taskName}" threw: '
        '$error\n$stackTrace',
      );
      WorkmanagerDebug.reportStatus(
        taskInfo,
        TaskStatus.failed,
        TaskResult(
          success: false,
          duration: DateTime.now().difference(started),
          error: error.toString(),
        ),
      );
      WorkmanagerDebug.reportException(taskInfo, error, stackTrace);
      return false;
    }
  }
}
