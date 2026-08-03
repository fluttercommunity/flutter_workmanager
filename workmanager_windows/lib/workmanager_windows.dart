// Copyright 2026 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

import 'execution.dart';
import 'src/payload_store.dart';
import 'src/process_runner.dart';
import 'src/schtasks.dart';

export 'execution.dart';

/// Windows implementation of [WorkmanagerPlatform] backed by Task Scheduler.
///
/// v1 uses the `schtasks` command line only — no COM, no C++ and no `win32`
/// dependency. Registering a task creates a per-user Task Scheduler task
/// whose action launches the app executable with
/// `--background-task <taskName>`; [maybeRunBackgroundTask] detects that
/// argument in `main()`, runs the registered callback handler headless and
/// exits (see `docs/windows.mdx`).
///
/// See the package README and `docs/windows.mdx` for the honest limitations
/// (per-user tasks, minute granularity, constraints accepted but ignored).
class WorkmanagerWindows extends WorkmanagerPlatform {
  /// Creates the implementation.
  ///
  /// [processRunner] and [payloadDirectory] are injectable for tests; by
  /// default real `schtasks` processes and `%LOCALAPPDATA%` are used.
  WorkmanagerWindows({
    ProcessRunner? processRunner,
    Directory? payloadDirectory,
  })  : processRunner = processRunner ?? const DefaultProcessRunner(),
        payloadStore = PayloadStore(
          payloadDirectory ?? defaultPayloadDirectory(),
        );

  /// Prefix for the Task Scheduler task names owned by this plugin.
  ///
  /// Registered tasks are stored as `workmanager_<uniqueName>` so
  /// [cancelAll] and [printScheduledTasks] can identify the plugin's tasks.
  static const String taskNamePrefix = 'workmanager_';

  /// The process runner used for every `schtasks` invocation.
  final ProcessRunner processRunner;

  /// The on-disk payload store.
  final PayloadStore payloadStore;

  /// The default payload directory:
  /// `%LOCALAPPDATA%\workmanager_windows\payloads`.
  static Directory defaultPayloadDirectory() {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    final base = localAppData ??
        '${Platform.environment['USERPROFILE'] ?? '.'}'
            '${Platform.pathSeparator}AppData${Platform.pathSeparator}Local';
    return Directory(
      '$base${Platform.pathSeparator}workmanager_windows'
      '${Platform.pathSeparator}payloads',
    );
  }

  /// Registers this implementation as the default [WorkmanagerPlatform] for
  /// Windows. Called by the generated plugin registrant.
  static void registerWith() {
    WorkmanagerPlatform.instance = WorkmanagerWindows();
  }

  /// Maps a [uniqueName] to the Task Scheduler task name.
  String taskIdFor(String uniqueName) => '$taskNamePrefix$uniqueName';

  /// Headless entry point, called at the very top of `main()`:
  ///
  /// ```dart
  /// void main(List<String> args) {
  ///   if (WorkmanagerWindows.maybeRunBackgroundTask(args, callbackDispatcher)) {
  ///     return;
  ///   }
  ///   runApp(const MyApp());
  /// }
  /// ```
  ///
  /// Returns `false` (and does nothing) when [args] do not contain
  /// `--background-task`, i.e. this is a normal app launch. When the
  /// argument is present, runs [callbackDispatcher] so it can register its
  /// handler, invokes the handler with the persisted payload, logs the result
  /// and terminates the process with an exit code Task Scheduler records
  /// (`0` success, `1` failure).
  static bool maybeRunBackgroundTask(
    List<String> args,
    Function callbackDispatcher,
  ) {
    final taskName = backgroundTaskNameFromArgs(args);
    if (taskName == null) {
      return false;
    }
    unawaited(_runHeadlessAndExit(taskName, args, callbackDispatcher));
    return true;
  }

  static Future<void> _runHeadlessAndExit(
    String taskName,
    List<String> args,
    Function callbackDispatcher,
  ) async {
    final exitCode = await runBackgroundTask(
      taskName,
      payloadFilePath: payloadFilePathFromArgs(args),
      callbackDispatcher: callbackDispatcher,
    );
    await stdout.flush();
    await stderr.flush();
    exit(exitCode);
  }

  @override
  Future<void> initialize(
    Function callbackDispatcher, {
    @Deprecated(
      'Use WorkmanagerDebug handlers instead. This parameter has no effect.',
    )
    bool isInDebugMode = false,
  }) async {
    WorkmanagerExecution.instance.callbackDispatcher = callbackDispatcher;
  }

  /// Registers the background task handler (mirrors
  /// `Workmanager().executeTask(...)`).
  ///
  /// The handler runs in the headless process Task Scheduler starts. It runs
  /// with the full Flutter engine available, but no window; keep the work
  /// short and return `true` on success (the return value becomes the
  /// process exit code Task Scheduler records as the task's last result).
  void executeTask(BackgroundTaskHandler backgroundTaskHandler) {
    WorkmanagerExecution.instance.executeTask(backgroundTaskHandler);
  }

  @override
  Future<void> registerOneOffTask(
    String uniqueName,
    String taskName, {
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    // Accepted for API parity; Task Scheduler has no expedited concept.
    bool expedited = false,
    ExistingWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    OutOfQuotaPolicy? outOfQuotaPolicy,
    ForegroundServiceConfig? foregroundServiceConfig,
  }) async {
    final payloadFile = await payloadStore.write(uniqueName, inputData);
    await _createTask(
      Schtasks.createOneOff(
        taskId: taskIdFor(uniqueName),
        action: _buildAction(taskName, payloadFile?.path),
        startTime: Schtasks.ensureFutureMinute(
          DateTime.now().add(initialDelay ?? Duration.zero),
        ),
      ),
      uniqueName,
    );
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
    final payloadFile = await payloadStore.write(uniqueName, inputData);
    await _createTask(
      Schtasks.createPeriodic(
        taskId: taskIdFor(uniqueName),
        action: _buildAction(taskName, payloadFile?.path),
        startTime: Schtasks.ensureFutureMinute(
          DateTime.now().add(initialDelay ?? Duration.zero),
        ),
        repeatMinutes: Schtasks.repeatMinutesFor(
          frequency ?? const Duration(minutes: 15),
        ),
      ),
      uniqueName,
    );
  }

  @override
  Future<void> registerProcessingTask(
    String uniqueName,
    String taskName, {
    Duration? initialDelay,
    Map<String, dynamic>? inputData,
    Constraints? constraints,
  }) async {
    throw UnsupportedError('Processing tasks are not supported on Windows.');
  }

  @override
  Future<void> registerHealthResearchTask(
    String uniqueName,
    String taskName, {
    Duration? initialDelay,
    Map<String, dynamic>? inputData,
    Constraints? constraints,
  }) async {
    throw UnsupportedError(
      'Health research tasks are not supported on Windows.',
    );
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
      'Continued processing tasks are not supported on Windows.',
    );
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    final taskId = taskIdFor(uniqueName);
    // Stop a running instance first (benign when the task is not running).
    await processRunner.run(Schtasks.executable, Schtasks.end(taskId));
    final deleteResult = await processRunner.run(
      Schtasks.executable,
      Schtasks.delete(taskId),
    );
    if (deleteResult.exitCode != 0 &&
        !_isMissingTask(deleteResult.stderr.toString())) {
      throw StateError(
        'Failed to cancel "$uniqueName": schtasks exited with '
        '${deleteResult.exitCode}.\n${deleteResult.stderr}',
      );
    }
    await payloadStore.delete(uniqueName);
  }

  @override
  Future<void> cancelByTag(String tag) async {
    throw UnsupportedError(
      'cancelByTag is not supported on Windows (v1). '
      'Use cancelByUniqueName or cancelAll instead.',
    );
  }

  @override
  Future<void> cancelAll() async {
    final taskIds = await _listOwnedTaskIds();
    for (final taskId in taskIds) {
      await processRunner.run(Schtasks.executable, Schtasks.end(taskId));
      final deleteResult = await processRunner.run(
        Schtasks.executable,
        Schtasks.delete(taskId),
      );
      if (deleteResult.exitCode != 0 &&
          !_isMissingTask(deleteResult.stderr.toString())) {
        throw StateError(
          'Failed to delete task "$taskId": schtasks exited with '
          '${deleteResult.exitCode}.\n${deleteResult.stderr}',
        );
      }
    }
    await payloadStore.deleteAll();
  }

  @override
  Future<bool> isScheduledByUniqueName(String uniqueName) async {
    final result = await processRunner.run(
      Schtasks.executable,
      Schtasks.query(taskIdFor(uniqueName)),
    );
    if (result.exitCode == 0) {
      return true;
    }
    if (result.exitCode == 1) {
      return false;
    }
    throw StateError(
      'Failed to query "$uniqueName": schtasks exited with '
      '${result.exitCode}.\n${result.stderr}',
    );
  }

  @override
  Future<String> printScheduledTasks() async {
    final result = await processRunner.run(
      Schtasks.executable,
      Schtasks.queryAllCsv(),
    );
    _throwIfFailed(result, 'query tasks');
    final owned = Schtasks.parseQueryCsv(result.stdout.toString())
        .where((row) => (row['TaskName'] ?? '').startsWith(taskNamePrefix))
        .toList();
    return jsonEncode(owned);
  }

  String _buildAction(String taskName, String? payloadFilePath) =>
      Schtasks.buildAction(
        executablePath: Platform.resolvedExecutable,
        taskName: taskName,
        payloadFilePath: payloadFilePath,
      );

  Future<void> _createTask(List<String> args, String uniqueName) async {
    final result = await processRunner.run(Schtasks.executable, args);
    if (result.exitCode != 0) {
      // Roll the payload back so no orphaned file outlives the failed task.
      await payloadStore.delete(uniqueName);
      throw StateError(
        'Failed to register task: schtasks exited with ${result.exitCode}.\n'
        '${result.stderr}',
      );
    }
  }

  Future<List<String>> _listOwnedTaskIds() async {
    final result = await processRunner.run(
      Schtasks.executable,
      Schtasks.queryAllCsv(),
    );
    _throwIfFailed(result, 'query tasks');
    return Schtasks.parseQueryCsv(result.stdout.toString())
        .map((row) => row['TaskName'])
        .whereType<String>()
        .where((name) => name.startsWith(taskNamePrefix))
        .toList();
  }

  void _throwIfFailed(ProcessResult result, String operation) {
    if (result.exitCode != 0) {
      throw StateError(
        'Failed to $operation: schtasks exited with ${result.exitCode}.\n'
        '${result.stderr}',
      );
    }
  }

  bool _isMissingTask(String stderr) {
    final normalized = stderr.toLowerCase();
    return normalized.contains('cannot find the file specified') ||
        normalized.contains('does not exist');
  }
}
