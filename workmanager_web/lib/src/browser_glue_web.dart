// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Minimal typed wrapper around the browser APIs used by `workmanager_web`.
///
/// This library compiles only on web platforms (`dart.library.js_interop`);
/// the VM twin is [BrowserGlue] in `browser_glue_stub.dart`.
class BrowserGlue {
  BrowserGlue._();

  static JSObject? get _navigator {
    try {
      return globalContext['navigator'] as JSObject?;
    } catch (_) {
      return null;
    }
  }

  /// Whether the current browser exposes `navigator.serviceWorker`.
  static bool get supportsServiceWorker {
    final navigator = _navigator;
    return navigator != null && navigator.has('serviceWorker');
  }

  /// Registers the Service Worker script, passing [dispatcherUrl] as a query
  /// parameter so the Service Worker can `importScripts()` the compiled Dart
  /// dispatcher bundle during its synchronous startup.
  ///
  /// Returns the ServiceWorkerRegistration, or `null` when unavailable.
  static Future<Object?> registerServiceWorker(
    String scriptUrl, {
    String? dispatcherUrl,
  }) async {
    final container = _navigator!['serviceWorker'] as JSObject;
    final url = dispatcherUrl == null
        ? scriptUrl
        : '$scriptUrl?dispatcherUrl=${Uri.encodeQueryComponent(dispatcherUrl)}';
    final promise =
        container.callMethod('register'.toJS, url.toJS) as JSPromise<JSAny?>;
    return await promise.toDart as JSObject?;
  }

  /// Posts [message] to the active Service Worker, if any.
  static Future<void> postToActiveServiceWorker(Object message) async {
    final registration = await _serviceWorkerRegistration();
    if (registration == null) {
      return;
    }
    final active = registration['active'] as JSObject?;
    if (active == null) {
      return;
    }
    active.callMethod('postMessage'.toJS, message.jsify());
  }

  /// Registers a listener for messages posted by the Service Worker.
  static void listenForServiceWorkerMessages(
    void Function(Object? data) handler,
  ) {
    final container = _navigator!['serviceWorker'] as JSObject;
    container.callMethod(
      'addEventListener'.toJS,
      'message'.toJS,
      ((JSObject event) {
        final data = event['data']?.dartify();
        handler(data);
      }).toJS,
    );
  }

  /// Registers a Periodic Background Sync tag.
  ///
  /// Returns `false` when `periodicSync` is unavailable in this browser.
  /// Throws when the registration is rejected (e.g. the PWA is not installed
  /// or the user has no engagement).
  static Future<bool> registerPeriodicSync(
    String tag,
    int minIntervalMs,
  ) async {
    final registration = await _serviceWorkerRegistration();
    if (registration == null || !registration.has('periodicSync')) {
      return false;
    }
    final manager = registration['periodicSync'] as JSObject;
    final promise = manager.callMethod(
      'register'.toJS,
      tag.toJS,
      <String, Object?>{'minInterval': minIntervalMs}.jsify(),
    ) as JSPromise<JSAny?>;
    await promise.toDart;
    return true;
  }

  /// Creates a Web Worker from [scriptUrl]. Returns an opaque worker handle,
  /// or `null` when Workers are unavailable.
  static Object? createWorker(String scriptUrl) {
    final constructor = globalContext['Worker'] as JSFunction?;
    if (constructor == null) {
      return null;
    }
    return constructor.callAsConstructor(scriptUrl.toJS) as JSObject?;
  }

  /// Registers a listener for messages posted by [worker].
  static void workerListen(
    Object? worker,
    void Function(Object? data) handler,
  ) {
    (worker as JSObject).callMethod(
      'addEventListener'.toJS,
      'message'.toJS,
      ((JSObject event) {
        final data = event['data']?.dartify();
        handler(data);
      }).toJS,
    );
  }

  /// Registers a listener for error events fired by [worker].
  static void workerListenForErrors(
    Object? worker,
    void Function(Object? error) handler,
  ) {
    (worker as JSObject).callMethod(
      'addEventListener'.toJS,
      'error'.toJS,
      ((JSObject event) {
        final message = (event['message'] as JSString?)?.toDart;
        handler(message ?? event);
      }).toJS,
    );
  }

  /// Posts [message] to [worker].
  static void workerPostMessage(Object? worker, Object message) {
    (worker as JSObject).callMethod('postMessage'.toJS, message.jsify());
  }

  static Future<JSObject?> _serviceWorkerRegistration() async {
    final container = _navigator!['serviceWorker'] as JSObject;
    final promise = container['ready'] as JSPromise<JSAny?>;
    return await promise.toDart as JSObject?;
  }
}
