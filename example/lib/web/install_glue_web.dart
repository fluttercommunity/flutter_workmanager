// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Captures the browser's `beforeinstallprompt` event so the demo can offer an
/// explicit "Install PWA" button (required for Periodic Background Sync).
///
/// Installing means the browser adds the app to the device like a native app
/// (launcher icon, standalone window) — that is what allows background tasks
/// to run with no tab open.
class InstallGlue {
  InstallGlue._();

  static JSAny? _deferredPrompt;

  /// Whether the demo app is installed as a PWA (set via the `appinstalled`
  /// event, which fires for both the in-app button and the browser's own
  /// address-bar install flow).
  static bool installed = false;

  /// Called whenever [installed] becomes true.
  static void Function()? onInstalled;

  /// Whether the browser fired `beforeinstallprompt` (i.e. a prompt can be
  /// shown right now).
  static bool get canPrompt => _deferredPrompt != null;

  /// Listens for `beforeinstallprompt` and `appinstalled` (called once at app
  /// startup).
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
    window.callMethod(
      'addEventListener'.toJS,
      'appinstalled'.toJS,
      ((JSObject _) {
        installed = true;
        onInstalled?.call();
      }).toJS,
    );
  }

  /// Shows the browser's PWA install prompt. Returns `true` when the user
  /// accepted (or the app is already installed); `false` when the browser has
  /// not offered a prompt yet or the user dismissed it.
  static Future<bool> promptInstall() async {
    if (installed) {
      return true;
    }
    final prompt = _deferredPrompt;
    if (prompt == null) {
      return false;
    }
    _deferredPrompt = null;
    final promise =
        (prompt as JSObject).callMethod('prompt'.toJS) as JSPromise<JSAny?>;
    final result = await promise.toDart;
    final outcome = (result as JSObject?)?['outcome']?.dartify();
    final accepted = outcome == 'accepted';
    if (accepted) {
      installed = true;
      onInstalled?.call();
    }
    return accepted;
  }
}
