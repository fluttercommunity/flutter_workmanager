// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

// IMPORTANT: this file must stay Flutter-free (no `package:flutter/...`
// imports). It is compiled with plain `dart compile js` into
// `web/background.dart.js` and executed both by the in-page Web Worker and by
// the Service Worker, neither of which can run the Flutter engine.

import 'package:workmanager_web/execution.dart';

/// Dispatcher used on the web: wired into the compiled worker bundle
/// (`web/background.dart`) and passed to `WorkmanagerWeb().initialize(...)` on
/// the page (fallback path).
@pragma('vm:entry-point')
void webCallbackDispatcher() {
  WorkmanagerExecution.instance.executeTask(handleWebBackgroundTask);
}

/// Pure-Dart background task handler.
///
/// The result is recorded by the runtime: when the page is open it appears in
/// the status panel immediately; when the Service Worker ran the task while
/// the page was closed, it is replayed on the next page load.
Future<bool> handleWebBackgroundTask(
  String taskName,
  Map<String, dynamic>? inputData,
) async {
  // A small CPU loop so the Web Worker's parallel execution is observable:
  // the UI stays responsive while this runs off the main thread.
  // ignore: unused_local_variable
  var checksum = 0;
  for (var i = 0; i < 2000000; i++) {
    checksum += i;
  }
  final input = inputData;
  return input != null && input['fail'] == true ? false : true;
}
