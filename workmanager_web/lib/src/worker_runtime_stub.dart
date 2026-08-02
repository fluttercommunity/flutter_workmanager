// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// VM-safe stand-in for [WorkmanagerWebWorker].
///
/// `dart:js_interop` is not importable on the VM. This stub keeps the package
/// analyzable on native platforms; the real runtime is only compiled into the
/// dart2js dispatcher bundle.
class WorkmanagerWebWorker {
  WorkmanagerWebWorker._();

  /// Runs [callbackDispatcher] in the current JS worker/service-worker global.
  ///
  /// Throws on non-web platforms.
  static void run(Function callbackDispatcher) {
    throw UnsupportedError(
      'WorkmanagerWebWorker can only run inside a compiled web worker bundle.',
    );
  }
}
