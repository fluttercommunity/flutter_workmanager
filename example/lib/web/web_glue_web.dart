// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Browser-only implementations of the small JS bridges used by the web demo
/// (landing page links + notifications). Kept behind a conditional export so
/// the example still compiles on native platforms (see `web_glue.dart`).

/// Opens [url] in a new browser tab.
void openUrl(String url) {
  final window = globalContext['window'] as JSObject?;
  if (window != null) {
    window.callMethod('open'.toJS, url.toJS);
  }
}

/// Requests the Web Notifications permission (must be called from a user
/// gesture in most browsers). Returns whether notifications are granted.
Future<bool> requestNotificationPermission() async {
  final notification = globalContext['Notification'];
  if (notification == null) {
    return false;
  }
  final notificationObj = notification as JSObject;
  final permission = notificationObj['permission']?.dartify();
  if (permission == 'granted') {
    return true;
  }
  if (permission == 'denied') {
    return false;
  }
  final result = await (notificationObj.callMethod('requestPermission'.toJS)
          as JSPromise<JSAny?>)
      .toDart;
  return result?.dartify() == 'granted';
}

/// Shows a page-side browser notification (only valid once permission is
/// granted).
void showPageNotification(String title, String body) {
  final notification = globalContext['Notification'];
  if (notification == null) {
    return;
  }
  (notification as JSFunction).callAsConstructor<JSObject>(
    title.toJS,
    <String, Object?>{'body': body}.jsify(),
  );
}

/// Shows a browser notification from inside a Service Worker (i.e. while the
/// page is closed) via `registration.showNotification`. No-op when not in a
/// Service Worker context.
void showServiceWorkerNotification(String title, String body) {
  final self = globalContext;
  if (!self.has('registration')) {
    return;
  }
  final registration = self['registration'] as JSObject;
  final promise = registration.callMethod(
    'showNotification'.toJS,
    title.toJS,
    <String, Object?>{'body': body, 'tag': 'workmanager-demo'}.jsify(),
  ) as JSPromise<JSAny?>;
  promise.toDart.catchError((Object _) => null);
}
