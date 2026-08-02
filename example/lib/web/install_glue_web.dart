// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Captures the browser's `beforeinstallprompt` event so the demo can offer an
/// explicit "Install PWA" button (required for Periodic Background Sync).
class InstallGlue {
  InstallGlue._();

  static JSAny? _deferredPrompt;

  /// Whether the browser fired `beforeinstallprompt`.
  static bool get canPrompt => _deferredPrompt != null;

  /// Listens for `beforeinstallprompt` (called once at app startup).
  static void listen() {
    final window = globalContext['window'] as JSObject?;
    if (window == null) {
      return;
    }
    window.callMethod(
      'addEventListener'.toJS,
      'beforeinstallprompt'.toJS,
      ((JSObject event) {
        event.callMethod('preventDefault'.toJS);
        _deferredPrompt = event;
      }).toJS,
    );
  }

  /// Shows the browser's PWA install prompt. Returns whether the app was
  /// installed.
  static Future<bool> promptInstall() async {
    final prompt = _deferredPrompt;
    if (prompt == null) {
      return false;
    }
    _deferredPrompt = null;
    final promise =
        (prompt as JSObject).callMethod('prompt'.toJS) as JSPromise<JSAny?>;
    await promise.toDart;
    return true;
  }
}
