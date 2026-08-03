// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'systemd.dart';

/// Builds the content of the persistent systemd user unit files written for
/// periodic tasks (a `.timer`/`.service` pair).
///
/// One-off tasks never touch these builders: they are scheduled with
/// transient `systemd-run` units instead.
class SystemdUnitFiles {
  SystemdUnitFiles._();

  /// Builds the `.service` unit for a periodic task.
  ///
  /// [description] is a human-readable summary shown by systemctl;
  /// [execArgs] is the full command line (binary plus `--background-task`
  /// arguments) run when the timer fires. `Type=oneshot` makes the unit
  /// complete when the app process exits, so a failing task shows up as a
  /// failed unit in the journal.
  static String service({
    required String description,
    required List<String> execArgs,
  }) {
    final exec = execArgs.map(SystemdUnitFiles.quoteExecArgument).join(' ');
    return '''
[Unit]
Description=${SystemdNames.description(description)}

[Service]
Type=oneshot
ExecStart=$exec
''';
  }

  /// Builds the `.timer` unit for a periodic task.
  ///
  /// [frequency] maps to `OnUnitActiveSec` (the timer re-fires this long
  /// after the previous run finished) and [initialDelay] maps to
  /// `OnStartupSec` (one-shot, relative to when the timer starts). When both
  /// are present the timer fires at `startup + initialDelay` first and then
  /// every [frequency]. `Persistent=true` gives WorkManager-style catch-up:
  /// a run missed while the system was off executes on the next wake.
  static String timer({
    required String description,
    required Duration frequency,
    Duration? initialDelay,
    required String serviceUnit,
  }) {
    final buffer = StringBuffer()
      ..writeln('[Unit]')
      ..writeln('Description=${SystemdNames.description(description)}')
      ..writeln()
      ..writeln('[Timer]');
    if (initialDelay != null && initialDelay > Duration.zero) {
      buffer.writeln('OnStartupSec=${initialDelay.inSeconds}');
    }
    buffer
      ..writeln('OnUnitActiveSec=${frequency.inSeconds}')
      ..writeln('Persistent=true')
      ..writeln('Unit=$serviceUnit')
      ..writeln()
      ..writeln('[Install]')
      ..writeln('WantedBy=timers.target');
    return buffer.toString();
  }

  /// Quotes a single [ExecStart](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html#ExecStart=)
  /// argument for a unit file.
  ///
  /// Arguments without whitespace, quotes or backslashes are passed through
  /// unchanged; anything else is double-quoted with `\` and `"` escaped.
  static String quoteExecArgument(String argument) {
    if (!argument.contains(RegExp(r'[\s"\\]'))) {
      return argument;
    }
    final escaped = argument.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '"$escaped"';
  }
}
