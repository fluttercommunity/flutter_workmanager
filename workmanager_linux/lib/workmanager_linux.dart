// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

import 'execution.dart';
import 'src/background_runner.dart';
import 'src/payload_store.dart';
import 'src/process_runner.dart';
import 'src/systemd.dart';
import 'src/systemd_units.dart';

export 'execution.dart';

/// Callback invoked when a running background task is stopped by the platform
/// before it finished.
///
/// Accepted for API parity with the native plugin; systemd never reports a
/// stop reason, so this handler is never invoked on Linux.
typedef BackgroundTaskStoppedHandler = Future<void> Function(
    String taskName, StopReason stopReason);

/// Linux implementation of [WorkmanagerPlatform] backed by systemd *user*
/// units.
///
/// Experimental. Scheduling runs through `systemctl --user` /
/// `systemd-run --user` and therefore requires a systemd user session (see
/// the `enable-linger` caveat in `docs/linux.mdx`). The package is pure Dart:
/// no Pigeon, no native code, and the process runner is injectable so tests
/// never need a real systemd.
///
/// How tasks are scheduled:
///
/// * **One-off tasks** — transient units via
///   `systemd-run --user --unit=workmanager-<hash> --on-active=<seconds>`,
///   or `--no-block` for an immediate run. Transient units vanish after the
///   task ran, so nothing lingers.
/// * **Periodic tasks** — a `.timer`/`.service` unit pair in
///   `~/.config/systemd/user/`. The timer uses `OnUnitActiveSec` for the
///   frequency and `Persistent=true` for WorkManager-style catch-up of runs
///   missed while the system was off. The service is `Type=oneshot` and
///   launches the app in headless `--background-task` mode.
///
/// See the package README and `docs/linux.mdx` for the honest list of
/// unsupported surface (constraints, backoff, tags, `cancelByTag`).
class WorkmanagerLinux extends WorkmanagerPlatform {
  /// Creates a Linux platform implementation.
  ///
  /// Every dependency is injectable so unit tests can run without systemd:
  /// [processRunner] receives all `systemctl`/`systemd-run` invocations,
  /// [binaryPath] is the app executable embedded in the units (defaults to
  /// [Platform.resolvedExecutable]), [unitsDirectory] is where persistent
  /// unit files are written (defaults to `$XDG_CONFIG_HOME/systemd/user` or
  /// `~/.config/systemd/user`) and [payloadDirectory] is where input data
  /// payloads are persisted (defaults to
  /// `$XDG_DATA_HOME/workmanager/payloads` or
  /// `~/.local/share/workmanager/payloads`).
  WorkmanagerLinux({
    ProcessRunner? processRunner,
    String? systemctlPath,
    String? systemdRunPath,
    String? binaryPath,
    String? unitsDirectory,
    String? payloadDirectory,
  })  : _processRunner = processRunner ?? const SystemProcessRunner(),
        _systemctl = systemctlPath ?? 'systemctl',
        _systemdRun = systemdRunPath ?? 'systemd-run',
        _binaryPath = binaryPath ?? Platform.resolvedExecutable,
        _unitsDirectory = unitsDirectory ?? _defaultUnitsDirectory(),
        _payloadStore = PayloadStore(
          Directory(payloadDirectory ?? _defaultPayloadDirectory()),
        );

  final ProcessRunner _processRunner;
  final String _systemctl;
  final String _systemdRun;
  final String _binaryPath;
  final String _unitsDirectory;
  final PayloadStore _payloadStore;

  late final SystemdCommands _commands =
      SystemdCommands(systemctl: _systemctl, systemdRun: _systemdRun);

  /// Registers this implementation as the default [WorkmanagerPlatform] for
  /// Linux. Called automatically by the `workmanager` package's platform
  /// selection; can also be called manually.
  static void registerWith() {
    WorkmanagerPlatform.instance = WorkmanagerLinux();
  }

  /// Registers the background task handler (mirrors
  /// `Workmanager().executeTask(...)`).
  ///
  /// Call this from your callback dispatcher. Unlike
  /// `Workmanager().executeTask`, it never touches platform channels, so it
  /// works in the headless process launched by systemd.
  ///
  /// [onTaskStopped] is accepted for API parity with the native plugin but
  /// has no effect on Linux.
  static void executeTask(
    BackgroundTaskHandler backgroundTaskHandler, {
    BackgroundTaskStoppedHandler? onTaskStopped,
  }) {
    WorkmanagerExecution.instance.executeTask(backgroundTaskHandler);
  }

  /// Detects and runs a headless `--background-task` invocation in [args].
  ///
  /// Call this at the top of `main()` so systemd-launched runs execute the
  /// registered callback and exit, instead of opening a window:
  ///
  /// ```dart
  /// Future<void> main(List<String> args) async {
  ///   if (await WorkmanagerLinux.maybeRunBackgroundTask(
  ///       args, callbackDispatcher)) {
  ///     return; // Handled: the process already logged and exited.
  ///   }
  ///   runApp(const MyApp());
  /// }
  /// ```
  ///
  /// Returns `false` (without side effects) when [args] contain no
  /// `--background-task` flag, so the app starts normally. When an
  /// invocation is found, the dispatcher runs, the payload is loaded, the
  /// registered handler is invoked and the process exits with `0` on success
  /// or `1` on failure (so systemd records failed runs in the journal).
  ///
  /// [payloadDirectory] overrides where payload files are looked up (only
  /// relevant for relative `--payload` paths).
  static Future<bool> maybeRunBackgroundTask(
    List<String> args,
    Function callbackDispatcher, {
    String? payloadDirectory,
  }) async {
    final invocation = BackgroundTaskInvocation.tryParse(args);
    if (invocation == null) {
      return false;
    }
    final runner = BackgroundTaskRunner(payloadDirectory: payloadDirectory);
    final success = await runner.run(invocation, callbackDispatcher);
    stdout.writeln(
      'workmanager_linux: background task "${invocation.taskName}" '
      'finished ${success ? 'successfully' : 'with failure'}',
    );
    exit(success ? 0 : 1);
  }

  @override
  Future<void> initialize(
    Function callbackDispatcher, {
    @Deprecated(
        'Use WorkmanagerDebug handlers instead. This parameter has no effect.')
    bool isInDebugMode = false,
  }) async {
    if (!Platform.isLinux) {
      throw UnsupportedError(
        'workmanager_linux can only be used on Linux. '
        'On other platforms use the `workmanager` package instead.',
      );
    }
    // Stored so headless invocations in the same process can find the
    // dispatcher; `maybeRunBackgroundTask` also receives it directly.
    WorkmanagerExecution.instance.callbackDispatcher = callbackDispatcher;
  }

  @override
  Future<void> registerOneOffTask(
    String uniqueName,
    String taskName, {
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    OutOfQuotaPolicy? outOfQuotaPolicy,
    ForegroundServiceConfig? foregroundServiceConfig,
  }) async {
    final payloadPath = await _payloadStore.write(uniqueName, inputData);
    final command = _commands.runOneOff(
      unit: SystemdNames.unit(uniqueName),
      delay: initialDelay ?? Duration.zero,
      appCommand: _appCommand(taskName, payloadPath),
    );
    await _run(command);
  }

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Duration? flexInterval,
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    ForegroundServiceConfig? foregroundServiceConfig,
  }) async {
    final resolvedFrequency = frequency ?? const Duration(minutes: 15);
    final payloadPath = await _payloadStore.write(uniqueName, inputData);
    final unit = SystemdNames.unit(uniqueName);
    final serviceUnit = '$unit.service';
    final timerUnit = '$unit.timer';
    final description =
        SystemdNames.description('Workmanager task "$taskName" ($uniqueName)');
    await _writeUnitFile(
      serviceUnit,
      SystemdUnitFiles.service(
        description: description,
        execArgs: _appCommand(taskName, payloadPath),
      ),
    );
    await _writeUnitFile(
      timerUnit,
      SystemdUnitFiles.timer(
        description: description,
        frequency: resolvedFrequency,
        initialDelay: initialDelay,
        serviceUnit: serviceUnit,
      ),
    );
    await _run(_commands.daemonReload());
    await _run(_commands.enableNow(timerUnit));
  }

  @override
  Future<void> registerProcessingTask(
    String uniqueName,
    String taskName, {
    Duration? initialDelay,
    Map<String, dynamic>? inputData,
    Constraints? constraints,
  }) async {
    throw UnsupportedError('Processing tasks are not supported on Linux.');
  }

  @override
  Future<void> registerHealthResearchTask(
    String uniqueName,
    String taskName, {
    Duration? initialDelay,
    Map<String, dynamic>? inputData,
    Constraints? constraints,
  }) async {
    throw UnsupportedError('Health research tasks are not supported on Linux.');
  }

  @override
  Future<void> registerContinuedProcessingTask(
    String uniqueName,
    String taskName, {
    String? title,
    String? subtitle,
    Map<String, dynamic>? inputData,
  }) async {
    throw UnsupportedError(
        'Continued processing tasks are not supported on Linux.');
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    final unit = SystemdNames.unit(uniqueName);
    await _runBestEffort(_commands.stop(unit));
    await _runBestEffort(_commands.disable('$unit.timer'));
    await _runBestEffort(_commands.resetFailed(unit));
    await _deleteUnitFiles(unit);
    await _runBestEffort(_commands.daemonReload());
    await _payloadStore.delete(uniqueName);
  }

  @override
  Future<void> cancelByTag(String tag) async {
    // A tag registry would be needed to map tags back to unique names; not
    // implemented in v1 (see docs/linux.mdx).
    throw UnsupportedError(
      'cancelByTag is not supported on Linux. Tags are accepted at '
      'registration time but not tracked; cancel tasks by unique name '
      'or use cancelAll.',
    );
  }

  @override
  Future<void> cancelAll() async {
    await _runBestEffort(_commands.stopAllTimers());
    await _runBestEffort(_commands.stopAllServices());
    await _runBestEffort(_commands.disableAllTimers());
    await _runBestEffort(_commands.resetFailedAll());
    await _clearUnitFiles();
    await _runBestEffort(_commands.daemonReload());
    await _payloadStore.clear();
  }

  @override
  Future<bool> isScheduledByUniqueName(String uniqueName) async {
    final result = await _runBestEffort(
        _commands.isActive(SystemdNames.timerUnit(uniqueName)));
    return result.exitCode == 0;
  }

  @override
  Future<String> printScheduledTasks() async {
    final result = await _runBestEffort(_commands.listTimers());
    final lines = result.stdout.toString().split('\n');
    return lines
        .where((line) => line.contains(SystemdNames.unitPrefix))
        .join('\n');
  }

  /// The command line embedded in units and passed to `systemd-run`:
  /// `<app> --background-task <taskName> [--payload <path>]`.
  List<String> _appCommand(String taskName, String? payloadPath) {
    return <String>[
      _binaryPath,
      '--background-task',
      taskName,
      if (payloadPath != null) '--payload',
      if (payloadPath != null) payloadPath,
    ];
  }

  Future<void> _writeUnitFile(String fileName, String content) async {
    final file = File('$_unitsDirectory/$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  Future<void> _deleteUnitFiles(String unit) async {
    final directory = Directory(_unitsDirectory);
    if (!await directory.exists()) {
      return;
    }
    for (final suffix in const <String>['.timer', '.service']) {
      final file = File('${directory.path}/$unit$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _clearUnitFiles() async {
    final directory = Directory(_unitsDirectory);
    if (!await directory.exists()) {
      return;
    }
    await for (final entity in directory.list()) {
      final name = entity.uri.pathSegments.last;
      final isOurs = name.startsWith(SystemdNames.unitPrefix) &&
          (name.endsWith('.timer') || name.endsWith('.service'));
      if (isOurs && entity is File) {
        await entity.delete();
      }
    }
  }

  /// Runs [command], turning a missing `systemctl`/`systemd-run` executable
  /// into a descriptive [StateError].
  Future<ProcessResult> _run(List<String> command) async {
    try {
      return await _processRunner.run(command.first, command.sublist(1));
    } on ProcessException catch (error) {
      throw StateError(
        'workmanager_linux: could not run "${command.first}" (${error.message}). '
        'Scheduling requires a systemd user session; see docs/linux.mdx for '
        'setup and the enable-linger caveat.',
      );
    }
  }

  /// Like [_run] but reports failures as a non-zero exit instead of
  /// throwing (used by cancellation and queries, where missing units are
  /// expected).
  Future<ProcessResult> _runBestEffort(List<String> command) async {
    try {
      return await _run(command);
    } on StateError {
      return ProcessResult(0, 1, '', '');
    }
  }
}

String _defaultUnitsDirectory() {
  final configHome = Platform.environment['XDG_CONFIG_HOME'];
  final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
  return '${configHome ?? '$home/.config'}/systemd/user';
}

String _defaultPayloadDirectory() {
  final dataHome = Platform.environment['XDG_DATA_HOME'];
  final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
  return '${dataHome ?? '$home/.local/share'}/workmanager/payloads';
}
