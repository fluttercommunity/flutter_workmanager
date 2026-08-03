// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// Flutter-free execution registry shared by the interactive app and the
/// headless `--background-task` process.
///
/// The headless process launched by a systemd unit runs the whole Flutter
/// engine (unlike the web worker bundle), so the dispatcher may use Flutter
/// plugins. The small execution contract still lives in this Flutter-free
/// library so the dispatcher can register its handler without touching
/// platform channels (there is no native counterpart on Linux to talk to).
///
/// A dispatcher written for Linux registers its handler with
/// [WorkmanagerExecution.executeTask]:
///
/// ```dart
/// @pragma('vm:entry-point')
/// void callbackDispatcher() {
///   WorkmanagerLinux.executeTask((taskName, inputData) async {
///     // Background work. Flutter plugins are allowed here.
///     return true;
///   });
/// }
/// ```
library;

/// Signature of the handler invoked when a background task runs.
///
/// [taskName] is the value passed when registering the task; [inputData] is
/// the registered input data (int, bool, double, String and their
/// lists/maps), loaded from the on-disk payload.
typedef BackgroundTaskHandler = Future<bool> Function(
  String taskName,
  Map<String, dynamic>? inputData,
);

/// Shared registry that holds the currently registered background task
/// handler.
///
/// One instance is shared by every execution context: the interactive app
/// (where the dispatcher registers its handler) and the headless
/// `--background-task` process (where the handler is invoked). Keeping the
/// registry in a plain class means the headless runner never has to set up
/// Flutter platform channels.
class WorkmanagerExecution {
  WorkmanagerExecution._();

  /// The process-wide singleton.
  static final WorkmanagerExecution instance = WorkmanagerExecution._();

  /// The handler registered by the most recent [executeTask] call.
  BackgroundTaskHandler? taskHandler;

  /// The callback dispatcher passed to
  /// `WorkmanagerLinux().initialize(...)` (or directly to
  /// [WorkmanagerLinux.maybeRunBackgroundTask]).
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
