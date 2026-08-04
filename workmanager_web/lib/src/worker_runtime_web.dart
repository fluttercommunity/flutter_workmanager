// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../execution.dart';
import 'worker_protocol.dart';

/// Runtime that boots the compiled callback-dispatcher bundle.
///
/// The bundle is a plain dart2js program with `main()` calling
/// [WorkmanagerWebWorker.run]. It works in two contexts:
///
/// * a dedicated Web Worker spawned by the page (real parallel execution), and
/// * the Service Worker global (the Service Worker `importScripts()`es the
///   bundle and invokes the exposed `__wmTrigger` function).
class WorkmanagerWebWorker {
  WorkmanagerWebWorker._();

  static bool _started = false;

  /// Runs [callbackDispatcher] in the current JS worker/service-worker global.
  ///
  /// Registers the task handler, exposes `self.__wmTrigger(taskName,
  /// inputData)` for the Service Worker JS, handles `executeTask` messages for
  /// dedicated-worker mode and posts a `ready` message on startup.
  static void run(Function callbackDispatcher) {
    if (_started) {
      return;
    }
    _started = true;
    WorkmanagerExecution.instance.callbackDispatcher = callbackDispatcher;
    callbackDispatcher();

    final self = globalContext;
    self['__wmTrigger'] = _trigger.toJS;
    self.callMethod(
      'addEventListener'.toJS,
      'message'.toJS,
      ((JSObject event) {
        final raw = event['data']?.dartify();
        if (raw is Map) {
          _handleMessage(raw.cast<Object?, Object?>());
        }
      }).toJS,
    );
    _wirePageMessaging();
    // The page waits for this message before routing work to the worker. It
    // is a harmless no-op inside a Service Worker global.
    self.callMethod(
      'postMessage'.toJS,
      <String, Object?>{'type': WorkerProtocol.typeReady}.jsify(),
    );
  }

  /// Wires `WorkmanagerExecution.sendToPage` so dispatcher code can push
  /// messages back to the page from either execution context:
  ///
  /// * **Dedicated Web Worker**: `self.postMessage` delivers directly to the
  ///   page that spawned the worker.
  /// * **Service Worker global**: there is no `postMessage` on the SW global;
  ///   messages are delivered to every open page via `clients.postMessage`.
  ///   When no page is open they are dropped (persistent results still flow
  ///   through the IndexedDB event log).
  static void _wirePageMessaging() {
    final self = globalContext;
    final execution = WorkmanagerExecution.instance;
    if (self.has('clients')) {
      execution.sendToPage = (Object? payload) {
        final message = WorkerProtocol.encodeWorkerMessage(payload).jsify();
        final clients = self['clients'] as JSObject;
        final promise = clients.callMethod(
          'matchAll'.toJS,
          <String, Object?>{
            'type': 'window'.toJS,
            'includeUncontrolled': true,
          }.jsify(),
        ) as JSPromise<JSAny?>;
        promise.toDart.then((Object? result) {
          if (result is! List) {
            return;
          }
          for (final client in result) {
            if (client is JSObject) {
              client.callMethod('postMessage'.toJS, message);
            }
          }
        });
      };
    } else {
      execution.sendToPage = (Object? payload) {
        self.callMethod(
          'postMessage'.toJS,
          WorkerProtocol.encodeWorkerMessage(payload).jsify(),
        );
      };
    }
  }

  static void _handleMessage(Map<Object?, Object?> raw) {
    // Free-form page -> worker messages go to the dispatcher's message
    // handler (when one is registered).
    final message = WorkerProtocol.decodeMessage(raw);
    if (message != null || raw['type'] == WorkerProtocol.typeMessage) {
      final handler = WorkmanagerExecution.instance.messageHandler;
      if (handler != null) {
        handler(message);
      }
      return;
    }
    final request = WorkerProtocol.decodeExecuteTask(raw);
    if (request == null) {
      return;
    }
    _runAndReply(
      request.requestId,
      request.taskName,
      request.inputData,
    );
  }

  static Future<void> _runAndReply(
    int requestId,
    String taskName,
    Object? inputData,
  ) async {
    final self = globalContext;
    final (result, error) = await _runHandler(taskName, inputData);
    self.callMethod(
      'postMessage'.toJS,
      WorkerProtocol.encodeResult(
        requestId: requestId,
        result: result,
        error: error,
      ).jsify(),
    );
  }

  /// The function exposed to the Service Worker JS as `self.__wmTrigger`.
  ///
  /// dart2js cannot convert async functions with `toJS`, so the Service Worker
  /// passes a JS completion callback; this function runs the handler and
  /// invokes it with `(result, error)`. The Service Worker wraps the callback
  /// in a `Promise` (see `wmCallDispatcher` in the Service Worker script).
  static void _trigger(
    String taskName,
    JSAny? rawInputData,
    JSFunction onDone,
  ) {
    _runAndCallBack(taskName, rawInputData, onDone);
  }

  static Future<void> _runAndCallBack(
    String taskName,
    JSAny? rawInputData,
    JSFunction onDone,
  ) async {
    final (result, error) = await _runHandler(
      taskName,
      rawInputData?.dartify(),
    );
    onDone.callAsFunction(
      null,
      result?.jsify(),
      error?.toJS,
    );
  }

  static Future<(Object?, String?)> _runHandler(
    String taskName,
    Object? inputData,
  ) async {
    String? error;
    Object? result;
    try {
      final handler = WorkmanagerExecution.instance.taskHandler;
      if (handler == null) {
        error = 'No background task handler registered. '
            'Did the callbackDispatcher call executeTask(...)?';
      } else {
        result = await handler(
          taskName,
          WorkmanagerExecution.instance.normalizeInputData(inputData),
        );
      }
    } catch (e) {
      error = e.toString();
    }
    return (result, error);
  }
}
