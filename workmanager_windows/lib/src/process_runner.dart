// Copyright 2026 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:io';

/// Runs external processes.
///
/// Injectable so `workmanager_windows` can be unit-tested on any host without
/// a Windows shell: tests substitute a fake that records the command lines
/// instead of executing them.
abstract interface class ProcessRunner {
  /// Runs [executable] with [arguments] and waits for it to complete.
  Future<ProcessResult> run(String executable, List<String> arguments);
}

/// Default [ProcessRunner] backed by `dart:io` [Process.run].
class DefaultProcessRunner implements ProcessRunner {
  const DefaultProcessRunner();

  @override
  Future<ProcessResult> run(String executable, List<String> arguments) =>
      Process.run(executable, arguments);
}
