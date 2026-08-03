// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:io';

/// Runs external processes for the workmanager Linux implementation.
///
/// Swappable in tests so no real `systemctl`/`systemd-run` is ever needed.
abstract class ProcessRunner {
  /// Runs [executable] with [arguments] and returns the result.
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  });
}

/// Default [ProcessRunner] backed by [Process.run].
class SystemProcessRunner implements ProcessRunner {
  /// Creates a runner.
  const SystemProcessRunner();

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
  }
}
