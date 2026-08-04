// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// Native-safe stand-in for the browser bridges (keeps the example analyzable
/// and compilable on native platforms). All calls are no-ops on non-web.
void openUrl(String url) {}

Future<bool> requestNotificationPermission() async => false;

void showPageNotification(String title, String body) {}

void showServiceWorkerNotification(String title, String body) {}
