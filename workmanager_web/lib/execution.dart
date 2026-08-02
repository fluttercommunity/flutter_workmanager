// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// Flutter-free execution registry shared by the page, the compiled Web Worker
/// bundle and (via that bundle) the Service Worker.
///
/// The callback dispatcher compiled into the worker bundle cannot import
/// Flutter packages, so the small execution contract used by a dispatcher
/// lives in this library instead of in `package:workmanager_web/workmanager_web.dart`.
///
/// A dispatcher written for the web registers its handler with
/// [WorkmanagerExecution.executeTask]:
///
/// ```dart
/// void callbackDispatcher() {
///   WorkmanagerExecution.instance.executeTask((taskName, inputData) async {
///     // Flutter-free background work only.
///     return true;
///   });
/// }
/// ```
library;

/// Signature of the handler invoked when a background task runs.
///
/// [taskName] is the value passed when registering the task; [inputData] is the
/// registered input data (int, bool, double, String and their lists/maps).
typedef BackgroundTaskHandler = Future<bool> Function(
  String taskName,
  Map<String, dynamic>? inputData,
);

/// Signature of the handler invoked when the page sends a free-form message
/// to the background worker (see `WorkmanagerWeb.sendMessageToWorker`).
///
/// The handler runs in the same context as the task handler (Web Worker,
/// Service Worker or in-page fallback), so it must stay Flutter-free too.
typedef WorkerMessageHandler = void Function(Object? payload);

/// Signature used by dispatcher code to push a free-form message back to the
/// page while a task or message handler is running.
///
/// The page receives it on `WorkmanagerWeb.workerMessages`. In the Service
/// Worker context the message is delivered to open pages via
/// `clients.postMessage`; when no page is open it is dropped.
typedef PageMessageSender = void Function(Object? payload);

/// Shared registry that holds the currently registered background task
/// handler.
///
/// One instance is shared by every execution context that runs the compiled
/// dispatcher bundle (the page fallback path, the in-page Web Worker and the
/// Service Worker), so dispatcher code stays identical everywhere.
class WorkmanagerExecution {
  WorkmanagerExecution._();

  /// The process-wide singleton.
  static final WorkmanagerExecution instance = WorkmanagerExecution._();

  /// The handler registered by the most recent [executeTask] call.
  BackgroundTaskHandler? taskHandler;

  /// The handler invoked when the page sends a message to the worker.
  ///
  /// Registered by the callback dispatcher (mirrors [executeTask]); the Web
  /// Worker and Service Worker runtimes route page messages here.
  WorkerMessageHandler? messageHandler;

  /// Sends a message back to the page, when a page is reachable.
  ///
  /// Wired by the runtime: the compiled worker bundle sets it to post to the
  /// owning page (or to open pages via `clients.postMessage` in the Service
  /// Worker context); the page sets it for the in-page fallback path. Dispatcher
  /// code can call this at any time; the page observes the message on
  /// `WorkmanagerWeb.workerMessages`.
  PageMessageSender? sendToPage;

  /// The callback dispatcher passed to `WorkmanagerWeb().initialize(...)`.
  ///
  /// Kept so the page can run the dispatcher itself when no Web Worker is
  /// available (in-page fallback execution).
  Function? callbackDispatcher;

  /// Registers [handler] as the background task handler (mirrors
  /// `Workmanager().executeTask(...)`).
  void executeTask(BackgroundTaskHandler handler) {
    taskHandler = handler;
  }

  /// Runs the registered handler with [taskName] and [rawInputData].
  ///
  /// Returns `false` when no handler has been registered yet.
  Future<bool> runTask(String taskName, Object? rawInputData) async {
    final handler = taskHandler;
    if (handler == null) {
      return false;
    }
    return handler(taskName, normalizeInputData(rawInputData));
  }

  /// Normalizes JSON-ish [value] into the `inputData` shape delivered to the
  /// background task handler (`Map<String, dynamic>` with recursively
  /// normalized nested maps and lists).
  Map<String, dynamic>? normalizeInputData(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Map) {
      final normalized = <String, dynamic>{};
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is String) {
          normalized[key] = normalizeInputDataValue(entry.value);
        }
      }
      return normalized;
    }
    return <String, dynamic>{'value': normalizeInputDataValue(value)};
  }

  Object? normalizeInputDataValue(Object? value) {
    if (value is Map) {
      final normalized = <String, dynamic>{};
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is String) {
          normalized[key] = normalizeInputDataValue(entry.value);
        }
      }
      return normalized;
    }
    if (value is List) {
      return value.map(normalizeInputDataValue).toList();
    }
    return value;
  }
}
