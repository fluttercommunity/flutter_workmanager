// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// Entry point for the compiled dispatcher bundle (see `worker.dart` docs in
/// the package README).
export 'src/worker_runtime_stub.dart'
    if (dart.library.js_interop) 'src/worker_runtime_web.dart';
