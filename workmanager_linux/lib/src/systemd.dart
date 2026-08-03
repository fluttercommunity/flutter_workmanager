// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// Deterministic systemd unit naming and command construction for the
/// workmanager Linux implementation.
///
/// Everything here is pure string/list construction: the platform
/// implementation feeds the results to a [ProcessRunner], and tests assert on
/// them with a fake runner — no systemd required.
library;

/// Derives systemd unit names from task [uniqueName]s.
class SystemdNames {
  SystemdNames._();

  /// Prefix of every unit created by this package.
  static const String unitPrefix = 'workmanager-';

  /// Stable 32-bit FNV-1a hash of [uniqueName], hex-encoded.
  ///
  /// Used instead of the raw unique name because systemd unit names only
  /// allow `[a-zA-Z0-9:_.\-]` and unique names are user-controlled. The hash
  /// is deterministic across processes, so registering, querying and
  /// cancelling a task all derive the same unit name without a registry.
  static String hash(String uniqueName) {
    var hash = 0x811c9dc5; // FNV-1a 32-bit offset basis.
    const prime = 0x01000193; // FNV-1a 32-bit prime.
    for (final codeUnit in uniqueName.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * prime) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Base unit name (no `.timer`/`.service` suffix) for [uniqueName].
  static String unit(String uniqueName) => '$unitPrefix${hash(uniqueName)}';

  /// Timer unit name for [uniqueName].
  static String timerUnit(String uniqueName) => '${unit(uniqueName)}.timer';

  /// Service unit name for [uniqueName].
  static String serviceUnit(String uniqueName) => '${unit(uniqueName)}.service';

  /// Sanitizes a human-readable [description] for use in a unit file
  /// `Description=` line (no newlines or control characters).
  static String description(String description) {
    return description.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ');
  }
}

/// Builds the argument lists for the `systemctl` / `systemd-run` invocations
/// used to schedule, query and cancel tasks.
class SystemdCommands {
  /// Creates a command builder.
  ///
  /// [systemctl] and [systemdRun] are the executables to invoke (usually
  /// `systemctl` and `systemd-run`; injectable for tests).
  const SystemdCommands({required this.systemctl, required this.systemdRun});

  /// The `systemctl` executable.
  final String systemctl;

  /// The `systemd-run` executable.
  final String systemdRun;

  /// Schedules a one-off task.
  ///
  /// A positive [delay] produces a transient timer
  /// (`--on-active=<seconds>`); a zero delay runs the command immediately as
  /// a transient service (`--no-block`). `--collect` unloads the transient
  /// units after they finish, even on failure, so failed one-off runs do not
  /// linger in the unit list.
  List<String> runOneOff({
    required String unit,
    required Duration delay,
    required List<String> appCommand,
  }) {
    final base = <String>[systemdRun, '--user', '--collect', '--unit=$unit'];
    if (delay > Duration.zero) {
      base.add('--on-active=${delay.inSeconds}');
    } else {
      base.add('--no-block');
    }
    return [...base, ...appCommand];
  }

  /// Reloads the user manager after unit files changed on disk.
  List<String> daemonReload() => <String>[systemctl, '--user', 'daemon-reload'];

  /// Enables and starts [timerUnit] (used for periodic tasks).
  List<String> enableNow(String timerUnit) =>
      <String>[systemctl, '--user', 'enable', '--now', timerUnit];

  /// Stops the timer and service units for [unit].
  List<String> stop(String unit) => <String>[
        systemctl, '--user', 'stop', '$unit.timer',
        '$unit.service', //
      ];

  /// Disables [timerUnit] so it does not start on the next login/boot.
  List<String> disable(String timerUnit) =>
      <String>[systemctl, '--user', 'disable', timerUnit];

  /// Clears the failed state of the units for [unit].
  List<String> resetFailed(String unit) => <String>[
        systemctl, '--user', 'reset-failed', '$unit.timer',
        '$unit.service', //
      ];

  /// Returns whether [timerUnit] is currently active.
  ///
  /// `systemctl is-active` exits 0 only when the unit is active; every other
  /// state (inactive, failed, unknown) is treated as "not scheduled".
  List<String> isActive(String timerUnit) =>
      <String>[systemctl, '--user', 'is-active', timerUnit];

  /// Lists all timers known to the user manager, machine readable.
  List<String> listTimers() => <String>[
        systemctl,
        '--user',
        'list-timers',
        '--all',
        '--no-legend',
        '--plain',
      ];

  /// Stops every workmanager timer (used by `cancelAll`).
  List<String> stopAllTimers() => <String>[
        systemctl,
        '--user',
        'stop',
        '${SystemdNames.unitPrefix}*.timer',
      ];

  /// Stops every workmanager service (used by `cancelAll`).
  List<String> stopAllServices() => <String>[
        systemctl,
        '--user',
        'stop',
        '${SystemdNames.unitPrefix}*.service',
      ];

  /// Disables every workmanager timer (used by `cancelAll`).
  List<String> disableAllTimers() => <String>[
        systemctl,
        '--user',
        'disable',
        '${SystemdNames.unitPrefix}*.timer',
      ];

  /// Clears the failed state of every workmanager unit (used by `cancelAll`).
  List<String> resetFailedAll() => <String>[
        systemctl,
        '--user',
        'reset-failed',
        '${SystemdNames.unitPrefix}*',
      ];
}
