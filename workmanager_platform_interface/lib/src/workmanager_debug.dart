// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'package:workmanager_platform_interface/workmanager_platform_interface.dart'
    show TaskStatus;

/// Information about a task for debugging purposes.
///
/// Mirrors `TaskDebugInfo` on the native (Android/iOS) debug API.
class TaskDebugInfo {
  const TaskDebugInfo({
    required this.taskName,
    this.uniqueName,
    this.inputData,
    required this.startTime,
  });

  /// The task name the work was registered with.
  final String taskName;

  /// The unique name the work was registered with, when known.
  final String? uniqueName;

  /// The input data the task was registered with, when known.
  final Map<String, dynamic>? inputData;

  /// When the task started executing.
  final DateTime startTime;
}

/// Result information for a completed task.
///
/// Mirrors `TaskResult` on the native (Android/iOS) debug API.
class TaskResult {
  const TaskResult({
    required this.success,
    required this.duration,
    this.error,
  });

  /// Whether the task handler reported success.
  final bool success;

  /// How long the task ran.
  final Duration duration;

  /// The failure message, when the task failed.
  final String? error;
}

/// Abstract debug handler for Workmanager events.
///
/// Mirror of the native `WorkmanagerDebug` API (Android/iOS): set a handler
/// with [WorkmanagerDebug.setCurrent] and override the callbacks you care
/// about. The default handler does nothing.
///
/// ```dart
/// WorkmanagerDebug.setCurrent(LoggingDebugHandler());
/// ```
///
/// Available on every platform: Android/iOS implementations emit natively
/// (same handler contract, minus platform context); web, linux and windows
/// emit from their Dart execution paths.
abstract class WorkmanagerDebug {
  const WorkmanagerDebug();

  static WorkmanagerDebug _current = _NoopDebugHandler();

  /// The currently registered debug handler.
  static WorkmanagerDebug get current => _current;

  /// Sets the global debug handler.
  static void setCurrent(WorkmanagerDebug handler) {
    _current = handler;
  }

  /// Restores the default no-op handler.
  static void reset() {
    _current = _NoopDebugHandler();
  }

  /// Called by platform implementations when a task status changes.
  static void reportStatus(
    TaskDebugInfo taskInfo,
    TaskStatus status,
    TaskResult? result,
  ) {
    _current.onTaskStatusUpdate(taskInfo, status, result);
  }

  /// Called by platform implementations when an exception is encountered
  /// during task processing.
  static void reportException(
    TaskDebugInfo? taskInfo,
    Object exception,
    StackTrace? stackTrace,
  ) {
    _current.onExceptionEncountered(taskInfo, exception, stackTrace);
  }

  /// Called when a task status changes. Default: do nothing.
  void onTaskStatusUpdate(
    TaskDebugInfo taskInfo,
    TaskStatus status,
    TaskResult? result,
  ) {}

  /// Called when an exception occurs during task processing. Default: do
  /// nothing.
  void onExceptionEncountered(
    TaskDebugInfo? taskInfo,
    Object exception,
    StackTrace? stackTrace,
  ) {}
}

class _NoopDebugHandler extends WorkmanagerDebug {}

/// Prints debug information to the console.
class LoggingDebugHandler extends WorkmanagerDebug {
  const LoggingDebugHandler();

  @override
  void onTaskStatusUpdate(
    TaskDebugInfo taskInfo,
    TaskStatus status,
    TaskResult? result,
  ) {
    final buffer = StringBuffer()
      ..write('[workmanager] ${taskInfo.taskName} -> $status');
    if (taskInfo.uniqueName != null) {
      buffer.write(' (${taskInfo.uniqueName})');
    }
    if (result != null) {
      buffer.write(
        ' — ${result.success ? 'OK' : 'FAILED'} in '
        '${result.duration.inMilliseconds}ms',
      );
      if (result.error != null) {
        buffer.write(': ${result.error}');
      }
    }
    // ignore: avoid_print
    print(buffer.toString());
  }

  @override
  void onExceptionEncountered(
    TaskDebugInfo? taskInfo,
    Object exception,
    StackTrace? stackTrace,
  ) {
    // ignore: avoid_print
    print(
      '[workmanager] exception in ${taskInfo?.taskName ?? 'unknown task'}: '
      '$exception',
    );
  }
}
