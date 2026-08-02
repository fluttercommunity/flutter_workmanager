// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

// Standalone, Flutter-free entrypoint compiled with dart2js into
// `web/background.dart.js`. That bundle is executed by the in-page Web Worker
// and `importScripts()`-ed by the Service Worker, so it must not import
// Flutter packages (see `lib/web/background_tasks.dart`).
//
// Rebuild with: `dart compile js -O2 web/background.dart -o web/background.dart.js`
// (or run `tool/build_web_background.sh`).

import 'package:workmanager_web/worker.dart';

import 'package:workmanager_example/web/background_tasks.dart';

@pragma('vm:entry-point')
void main() {
  WorkmanagerWebWorker.run(webCallbackDispatcher);
}
