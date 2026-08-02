// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// VM-safe stand-in for [BrowserGlue].
///
/// `dart:js_interop` is not importable on the VM, so this stub keeps the
/// package analyzable and testable on native platforms. None of these members
/// should ever be reached at runtime on the VM: [BrowserGlue] calls are
/// guarded by `kIsWeb`.
class BrowserGlue {
  BrowserGlue._();

  /// Whether the current browser exposes `navigator.serviceWorker`.
  static bool get supportsServiceWorker => false;

  /// Registers the Service Worker script. Returns the registration, or `null`
  /// when registration is unavailable.
  static Future<Object?> registerServiceWorker(
    String scriptUrl, {
    String? dispatcherUrl,
  }) async {
    throw UnsupportedError('BrowserGlue is only available on web.');
  }

  /// Posts [message] to the active Service Worker, if any.
  static Future<void> postToActiveServiceWorker(Object message) async {
    throw UnsupportedError('BrowserGlue is only available on web.');
  }

  /// Registers a listener for messages posted by the Service Worker.
  static void listenForServiceWorkerMessages(
    void Function(Object? data) handler,
  ) {
    throw UnsupportedError('BrowserGlue is only available on web.');
  }

  /// Registers a Periodic Background Sync tag. Returns `false` when the API is
  /// unavailable.
  static Future<bool> registerPeriodicSync(
    String tag,
    int minIntervalMs,
  ) async {
    throw UnsupportedError('BrowserGlue is only available on web.');
  }

  /// Creates a Web Worker from [scriptUrl]. Returns an opaque worker handle,
  /// or `null` when Workers are unavailable.
  static Object? createWorker(String scriptUrl) {
    throw UnsupportedError('BrowserGlue is only available on web.');
  }

  /// Registers a listener for messages posted by [worker].
  static void workerListen(
      Object? worker, void Function(Object? data) handler) {
    throw UnsupportedError('BrowserGlue is only available on web.');
  }

  /// Registers a listener for error events fired by [worker].
  static void workerListenForErrors(
    Object? worker,
    void Function(Object? error) handler,
  ) {
    throw UnsupportedError('BrowserGlue is only available on web.');
  }

  /// Posts [message] to [worker].
  static void workerPostMessage(Object? worker, Object message) {
    throw UnsupportedError('BrowserGlue is only available on web.');
  }
}
