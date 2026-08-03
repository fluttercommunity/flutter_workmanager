import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';
import 'package:workmanager_android/workmanager_android.dart';
import 'package:workmanager_apple/workmanager_apple.dart';
import 'package:workmanager_web/workmanager_web.dart';

/// Function that executes your background work.
/// You should return the [BackgroundTaskResult] describing the outcome.
///
/// [taskName] Returns the value you provided when registering the task.
/// iOS will pass [Workmanager.iOSBackgroundTask] (for background-fetch) or
/// custom task IDs for BGTaskScheduler based tasks.
///
/// The behavior differs on each platform:
/// - Android: [BackgroundTaskResult.retry] reschedules the work based on the
///   policy given in [Workmanager.registerOneOffTask], while
///   [BackgroundTaskResult.failure] stops the chain permanently.
/// - iOS: [BackgroundTaskResult.retry] and [BackgroundTaskResult.failure] both
///   report a failed fetch; there is no automatic retry, so schedule another
///   attempt using [Workmanager.registerOneOffTask]. This depends on
///   BGTaskScheduler being set up correctly. Please follow the README for
///   instructions.
///
/// If the handler throws (or the returned Future completes with an error),
/// the task is treated as a permanent failure on both platforms — Android
/// `Result.failure()`, iOS a failed fetch — and is not retried.
typedef BackgroundTaskHandler = Future<BackgroundTaskResult> Function(
    String taskName, Map<String, dynamic>? inputData);

/// Callback invoked when a running background task is stopped by the platform
/// before it finished.
///
/// This is Android-only: it fires when WorkManager stops a worker that is
/// currently running (cancelled, timed out, preempted, ...). iOS has no
/// equivalent concept — `cancelByUniqueName` there only removes pending
/// BGTaskScheduler requests.
///
/// [taskName] is the same value passed to the [BackgroundTaskHandler].
/// [stopReason] describes why the task was stopped; on Android versions
/// before 12 (API 31) it is always [StopReason.unknown].
///
/// Return promptly: the platform tears the task's engine down once this
/// handler completes, so long-running work should be kept to quick state
/// persistence and cleanup.
typedef BackgroundTaskStoppedHandler = Future<void> Function(
    String taskName, StopReason stopReason);

/// Make sure you followed the platform setup steps first before trying to register any task.
///
/// Android:
/// - Custom Application class
///
/// iOS:
/// - Enabled the Background Fetch API
///
/// Inside your Dart code
///
/// Initialize the plugin first
///
/// ```
/// @pragma('vm:entry-point')
/// void callbackDispatcher() {
///   Workmanager().executeTask((taskName, inputData) {
///     switch(taskName) {
///       case "":
///         print("Replace this print statement with your code that should be executed in the background here");
///         break;
///     }
///     return Future.value(true);
///   });
/// }
///
/// void main() {
///   Workmanager().initialize(callbackDispatcher);
/// }
/// ```
///
/// ## You can schedule a specific iOS task using:
/// - `Workmanager().registerOneOffTask()`
/// Please read the documentation on limitations for background processing on iOS.
///
///
/// iOS periodic background fetch task is automatically scheduled if you setup the plugin properly for Background Fetch.
///
/// If you are targeting iOS 13+, you can use `Workmanager().registerPeriodicTask()`
///
/// Note: On iOS 13+, adding a BGTaskSchedulerPermittedIdentifiers key to the Info.plist
/// disables the performFetchWithCompletionHandler and setMinimumBackgroundFetchInterval
/// methods, which means you cannot use both old Background Fetch and new registerPeriodicTask
/// at the same time, you have to choose one based on your minimum iOS target version.
/// For details see [Using background tasks to update your app](https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background/using_background_tasks_to_update_your_app/)
///
///
/// ## You can schedule Android tasks using:
/// - `Workmanager().registerOneOffTask()` or `Workmanager().registerPeriodicTask()`
class Workmanager {
  factory Workmanager() => _instance;

  Workmanager._internal() {
    _ensurePlatformImplementation();
  }

  static final Workmanager _instance = Workmanager._internal();

  static void _ensurePlatformImplementation() {
    if (kIsWeb) {
      if (WorkmanagerPlatform.instance is! WorkmanagerWeb) {
        WorkmanagerPlatform.instance = WorkmanagerWeb();
      }
      return;
    }
    if (WorkmanagerPlatform.instance is! WorkmanagerAndroid &&
        WorkmanagerPlatform.instance is! WorkmanagerApple) {
      if (Platform.isAndroid) {
        WorkmanagerPlatform.instance = WorkmanagerAndroid();
      } else if (Platform.isIOS || Platform.isMacOS) {
        WorkmanagerPlatform.instance = WorkmanagerApple();
      }
    }
  }

  /// Use this constant inside your callbackDispatcher to identify when an iOS Background Fetch occurred.
  ///
  /// ```
  /// @pragma('vm:entry-point')
  /// void callbackDispatcher() {
  ///   Workmanager().executeTask((taskName, inputData) {
  ///      switch (taskName) {
  ///        case Workmanager.iOSBackgroundTask:
  ///          stderr.writeln("The iOS background fetch was triggered");
  ///          break;
  ///      }
  ///
  ///     return Future.value(true);
  ///   });
  /// }
  /// ```
  static const String iOSBackgroundTask = "iOSPerformFetch";

  static BackgroundTaskHandler? _backgroundTaskHandler;
  static BackgroundTaskStoppedHandler? _onTaskStoppedHandler;
  static late final WorkmanagerFlutterApi _flutterApi;

  /// The callback dispatcher registered via [initialize], kept so in-process
  /// (main-engine) one-off tasks can lazily register their task handler on
  /// first execution without spawning a second Flutter engine.
  static Function? _callbackDispatcher;

  /// Whether [_callbackDispatcher] has already run in the current isolate.
  static bool _inProcessDispatcherStarted = false;

  /// Flutter API handler registered on the current isolate's messenger by
  /// [initialize] so the native side can execute tasks on the running engine.
  static WorkmanagerFlutterApi? _inProcessFlutterApi;

  /// Platform implementation
  static WorkmanagerPlatform get _platform => WorkmanagerPlatform.instance;

  /// Initialize the Workmanager with a [callbackDispatcher].
  ///
  /// The [callbackDispatcher] is a top level function which will be invoked by Android or iOS whenever a scheduled task is due.
  ///
  /// [isInDebugMode] is deprecated and has no effect. Use WorkmanagerDebug handlers instead.
  Future<void> initialize(
    Function callbackDispatcher, {
    @Deprecated(
        'Use WorkmanagerDebug handlers instead. This parameter has no effect.')
    bool isInDebugMode = false,
  }) async {
    await _platform.initialize(callbackDispatcher,
        // ignore: deprecated_member_use
        isInDebugMode: isInDebugMode);
    _prepareInProcessExecution(callbackDispatcher);
  }

  /// Registers the Flutter API surface on the current isolate's messenger so
  /// one-off tasks can execute on the running (main) engine instead of a second
  /// full Flutter engine. The [callbackDispatcher] itself runs lazily on the
  /// first in-process task (see
  /// [_WorkmanagerFlutterApiImpl.backgroundChannelInitialized]).
  void _prepareInProcessExecution(Function callbackDispatcher) {
    _callbackDispatcher = callbackDispatcher;
    if (_inProcessFlutterApi == null) {
      _inProcessFlutterApi = _WorkmanagerFlutterApiImpl();
      WorkmanagerFlutterApi.setUp(_inProcessFlutterApi!);
    }
  }

  /// This method needs to be called from within your [callbackDispatcher].
  ///
  /// [backgroundTaskHandler] is the callback that is provided when a background task is run.
  ///
  /// This is used by iOS and Android to identify which task was selected to run in the background.
  /// The [BackgroundTaskHandler] will provide you with the [taskName] and the [inputData].
  /// The [taskName] will always be the value you provided when registering the task.
  /// On iOS, periodic and processing tasks are identified by the BGTaskScheduler
  /// identifier, so for those task types the handler receives the [uniqueName]
  /// you registered the task with.
  /// The [inputData] will contain all the data you registered the task with.
  ///
  /// You need to return a [Future<BackgroundTaskResult>] that tells the OS how
  /// the task went: [BackgroundTaskResult.success], retry or failure.
  ///
  /// You can perfectly call other Flutter plugins inside this callback, as the callback is simply running within a Flutter background isolate.
  ///
  /// Scheduling other background tasks inside the [BackgroundTaskHandler] is allowed.
  ///
  /// [onTaskStopped] is an optional handler invoked when the platform stops a
  /// running task before it finishes (Android only, see
  /// [BackgroundTaskStoppedHandler]).
  void executeTask(
    BackgroundTaskHandler backgroundTaskHandler, {
    BackgroundTaskStoppedHandler? onTaskStopped,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final marker =
          File('${Directory.systemTemp.path}/wm_execute_task_marker');
      marker.writeAsStringSync('executeTask called ${DateTime.now()}');
    } catch (_) {}

    _backgroundTaskHandler = backgroundTaskHandler;
    _onTaskStoppedHandler = onTaskStopped;
    _flutterApi = _WorkmanagerFlutterApiImpl();
    WorkmanagerFlutterApi.setUp(_flutterApi);

    await _flutterApi.backgroundChannelInitialized();
  }

  /// Schedule a one-off task.
  ///
  /// A [uniqueName] is required so only one task can be registered.
  ///
  /// Calling this method again with the same [uniqueName] will update the current pending task, unless an [ExistingWorkPolicy] is provided.
  ///
  /// - [taskName]: is the value that will be returned in the [BackgroundTaskHandler]. Supported on both Android and iOS.
  /// - [inputData]: is the input data for task. Valid value types are: int, bool, double, String and their list
  /// - [initialDelay]: is an [Duration] after which the task will run.
  ///   On Android the task is scheduled by the OS and survives app restarts.
  ///   On iOS the delay is honored while the app stays alive, but iOS may
  ///   terminate the app before the task can run (background execution is
  ///   limited to a short budget). Use a processing task for long-running work.
  /// - [constraints]: are the requirements that need to be met before the task runs.
  /// - [backoffPolicy]: is the backoff policy to use when retrying work.
  /// - [backoffPolicyDelay]: is the delay for the backoff policy.
  /// - [tag]: is an optional tag that can be used to identify or cancel the task.
  /// - [existingWorkPolicy]: is the policy to use when work with the same [uniqueName] already exists.
  /// - [outOfQuotaPolicy]: is the policy to use when the device is out of quota. (Android only)
  /// - [foregroundServiceConfig]: when provided (Android only), the worker
  ///   runs as an Android foreground service for the whole duration of the
  ///   task. This allows work to keep running beyond the usual background
  ///   execution limits, in exchange for a persistent notification. See
  ///   [ForegroundServiceConfig] for the available options.
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
    return _platform.registerOneOffTask(
      uniqueName,
      taskName,
      inputData: inputData,
      initialDelay: initialDelay,
      constraints: constraints,
      existingWorkPolicy: existingWorkPolicy,
      backoffPolicy: backoffPolicy,
      backoffPolicyDelay: backoffPolicyDelay,
      tag: tag,
      outOfQuotaPolicy: outOfQuotaPolicy,
      foregroundServiceConfig: foregroundServiceConfig,
    );
  }

  /// Schedules a periodic task that will run every provided [frequency].
  ///
  /// On iOS it is not guaranteed when or how often it will run, iOS will schedule
  /// it as per user's App usage pattern, iOS might terminate the task or throttle
  /// it's frequency if it takes more than 30 seconds.
  ///
  /// A [uniqueName] is required so only one task can be registered.
  /// The [taskName] is the value that will be returned in the [BackgroundTaskHandler].
  /// On iOS the handler receives the BGTaskScheduler identifier (the [uniqueName]),
  /// because the identifier is what you register in Info.plist.
  /// a [frequency] is not required and will be defaulted to 15 minutes if not provided.
  /// a [frequency] has a minimum of 15 min. Android will automatically change your frequency to 15 min if you have configured a lower frequency.
  /// the [flexInterval] If the nature of the work is time-sensitive, you can configure the PeriodicWorkRequest to run in a flexible period at each interval.
  /// The [inputData] is the input data for task. Valid value types are: int, bool, double, String and their list
  ///
  /// On iOS, [frequency] is not used: the scheduling hint comes from
  /// [initialDelay] (mapped to BGTaskScheduler's `earliestBeginDate`). The
  /// launch handler is registered automatically by the plugin, so no
  /// `AppDelegate.swift` code is required.
  /// The [inputData] is the input data for task. Valid value types are: int, bool, double, String and their list.
  ///
  /// For iOS see Apple docs:
  /// [iOS 13+ Using background tasks to update your app](https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background/using_background_tasks_to_update_your_app/)
  ///
  /// [iOS 13+ BGAppRefreshTask](https://developer.apple.com/documentation/backgroundtasks/bgapprefreshtask/)
  ///
  /// [foregroundServiceConfig]: when provided (Android only), the worker runs
  /// as an Android foreground service for the whole duration of the task,
  /// showing a persistent notification. See [ForegroundServiceConfig].
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
    return _platform.registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: frequency,
      flexInterval: flexInterval,
      inputData: inputData,
      initialDelay: initialDelay,
      constraints: constraints,
      existingWorkPolicy: existingWorkPolicy,
      backoffPolicy: backoffPolicy,
      backoffPolicyDelay: backoffPolicyDelay,
      tag: tag,
      foregroundServiceConfig: foregroundServiceConfig,
    );
  }

  /// Checks whether a period task is scheduled by its [uniqueName].
  ///
  /// Scheduled means the work state is either ENQUEUED or RUNNING
  ///
  /// Only available on Android.
  Future<bool> isScheduledByUniqueName(String uniqueName) async {
    return _platform.isScheduledByUniqueName(uniqueName);
  }

  /// Schedule a background long running task, currently only available on iOS.
  ///
  /// Processing tasks are for long processes like data processing and app maintenance.
  /// Processing tasks can run for minutes, but the system can interrupt these.
  /// Processing tasks run only when the device is idle. iOS might terminate any
  /// running background processing tasks when the user starts using the device.
  /// However background refresh tasks aren't affected.
  ///
  /// For iOS see Apple docs:
  /// [iOS 13+ Using background tasks to update your app](https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background/using_background_tasks_to_update_your_app/)
  ///
  /// [iOS 13+ BGProcessingTask](https://developer.apple.com/documentation/backgroundtasks/bgprocessingtask/)
  Future<void> registerProcessingTask(
    String uniqueName,
    String taskName, {
    Duration? initialDelay,
    Map<String, dynamic>? inputData,
    Constraints? constraints,
  }) async {
    return _platform.registerProcessingTask(
      uniqueName,
      taskName,
      initialDelay: initialDelay,
      inputData: inputData,
      constraints: constraints,
    );
  }

  /// Register a health research task (iOS 17+ only, health research apps).
  ///
  /// Health research tasks are scheduled with
  /// [BGHealthResearchTaskRequest](https://developer.apple.com/documentation/backgroundtasks/bghealthresearchtaskrequest),
  /// which iOS delivers with additional priority and reliability for
  /// processing that is essential to a health research study.
  ///
  /// Availability:
  /// - iOS 17+ only. On older iOS versions the call fails with an
  ///   [UnsupportedError] (platform) or a Pigeon error (iOS < 17).
  /// - Android and macOS do not support this task type.
  ///
  /// App requirements (checked by Apple at submission time, not by this
  /// plugin):
  /// - The app must be a [Health Research Study container](https://developer.apple.com/documentation/healthkit)
  ///   with the `com.apple.developer.backgroundtasks.healthresearch`
  ///   entitlement.
  /// - The user must have opted in to the relevant study.
  /// - The task identifier must be listed in `BGTaskSchedulerPermittedIdentifiers`
  ///   in Info.plist, and `BGTaskSchedulerPermittedIdentifiers` registration
  ///   happens automatically by the plugin (see the docs for
  ///   `WorkmanagerPlugin.registerBGHealthResearchTask(withIdentifier:)`).
  ///
  /// Like processing tasks, health research tasks run while the device is
  /// idle, can run for minutes, and may be interrupted by the system. The
  /// [taskName] is the value returned in the [BackgroundTaskHandler]; on iOS
  /// the handler receives the BGTaskScheduler identifier (the [uniqueName]).
  ///
  /// [uniqueName] is a required unique identifier for the task.
  /// [taskName] is the value returned in the [BackgroundTaskHandler].
  /// [initialDelay] is the earliest-begin hint passed to the system.
  /// [inputData] is the input data for the task (int, bool, double, String
  /// and their lists).
  /// [constraints] maps to the BGProcessingTaskRequest network/charging
  /// requirements (only `networkType` and `requiresCharging` are honored on
  /// iOS).
  Future<void> registerHealthResearchTask(
    String uniqueName,
    String taskName, {
    Duration? initialDelay,
    Map<String, dynamic>? inputData,
    Constraints? constraints,
  }) async {
    return _platform.registerHealthResearchTask(
      uniqueName,
      taskName,
      initialDelay: initialDelay,
      inputData: inputData,
      constraints: constraints,
    );
  }

  /// Register a continued processing task (iOS 26+ only).
  ///
  /// Continued processing tasks are scheduled with
  /// [BGContinuedProcessingTaskRequest](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest),
  /// which begins immediately or shortly after submission and is allowed to
  /// continue running even if the app is backgrounded. The system presents a
  /// Live Activity to the user while the task is in progress.
  ///
  /// Availability:
  /// - iOS 26+ only. On older iOS versions the call fails with a Pigeon error.
  /// - Android and macOS do not support this task type.
  ///
  /// App requirements (checked by Apple at submission time, not by this
  /// plugin):
  /// - The [uniqueName] must use wildcard notation ending in `.*`, with a
  ///   prefix that contains the app's bundle identifier (e.g.
  ///   `com.example.app.continuedProcessing.*`).
  /// - The identifier must be listed in `BGTaskSchedulerPermittedIdentifiers`
  ///   in Info.plist, and `UIBackgroundModes` must include `processing`.
  ///
  /// Unlike processing tasks, continued processing tasks are not limited to
  /// idle devices, but the system still enforces expiration based on changing
  /// system conditions and user input. Tasks are expected to report progress
  /// (NSProgress); the plugin does not currently plumb progress from Dart, so
  /// very long-running callbacks that appear stalled may be expired by the
  /// scheduler.
  ///
  /// [uniqueName] is a required unique identifier for the task.
  /// [taskName] is the value returned in the [BackgroundTaskHandler]; on iOS
  /// the handler receives the BGTaskScheduler identifier (the [uniqueName]).
  /// [title] and [subtitle] are the localized strings shown to the user in
  /// the Live Activity while the task runs.
  /// [inputData] is the input data for the task (int, bool, double, String
  /// and their lists).
  Future<void> registerContinuedProcessingTask(
    String uniqueName,
    String taskName, {
    String? title,
    String? subtitle,
    Map<String, dynamic>? inputData,
  }) async {
    return _platform.registerContinuedProcessingTask(
      uniqueName,
      taskName,
      title: title,
      subtitle: subtitle,
      inputData: inputData,
    );
  }

  /// Cancels task by [uniqueName]
  Future<void> cancelByUniqueName(String uniqueName) async =>
      _platform.cancelByUniqueName(uniqueName);

  /// Cancels task by [tag]
  Future<void> cancelByTag(String tag) async => _platform.cancelByTag(tag);

  /// Cancels all tasks
  Future<void> cancelAll() async => _platform.cancelAll();

  /// Prints details of un-executed scheduled tasks to console. To be used during
  /// development/debugging.
  ///
  /// Currently only supported on iOS and only on iOS 13+.
  /// Returns a string containing the scheduled tasks information.
  Future<String> printScheduledTasks() async => _platform.printScheduledTasks();
}

/// Converts inputData from Pigeon format, filtering out null keys and
/// normalizing nested containers.
///
/// The platform channel codec delivers nested lists as `List<dynamic>` and
/// nested maps as `Map<dynamic, dynamic>`, which makes re-passing `inputData`
/// into other tasks error-prone (e.g. `inputData['keys'] as List<String>`
/// fails). This conversion:
/// - turns nested maps into `Map<String, dynamic>`,
/// - keeps the element type of homogeneous nested lists (e.g. `List<String>`),
/// - leaves heterogeneous lists as `List<dynamic>`.
@visibleForTesting
Map<String, dynamic>? convertPigeonInputData(Map<String?, Object?>? inputData) {
  if (inputData == null) {
    return null;
  }
  final convertedInputData = <String, dynamic>{};
  for (final entry in inputData.entries) {
    final key = entry.key;
    if (key != null) {
      convertedInputData[key] = normalizeInputDataValue(entry.value);
    }
  }
  return convertedInputData;
}

/// Recursively normalizes a single `inputData` value for delivery to the
/// background task callback. See [convertPigeonInputData].
@visibleForTesting
Object? normalizeInputDataValue(Object? value) {
  if (value is Map) {
    final normalized = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is String) {
        normalized[key] = normalizeInputDataValue(entry.value);
      }
    }
    return normalized;
  }
  if (value is List) {
    final normalized = value.map(normalizeInputDataValue).toList();
    if (normalized.isEmpty) {
      return normalized;
    }
    if (normalized.every((element) => element is String)) {
      return List<String>.from(normalized);
    }
    if (normalized.every((element) => element is int)) {
      return List<int>.from(normalized);
    }
    if (normalized.every((element) => element is double)) {
      return List<double>.from(normalized);
    }
    if (normalized.every((element) => element is bool)) {
      return List<bool>.from(normalized);
    }
    return normalized;
  }
  return value;
}

/// Implementation of WorkmanagerFlutterApi for handling background task execution
class _WorkmanagerFlutterApiImpl extends WorkmanagerFlutterApi {
  @override
  Future<void> backgroundChannelInitialized() async {
    // On the main engine the callbackDispatcher has not run yet (it normally
    // runs inside a dedicated headless engine). Run it once so the task
    // handler is registered before executeTask is invoked, letting one-off
    // tasks execute in-process without spawning a second engine (fixes #653).
    final dispatcher = Workmanager._callbackDispatcher;
    if (dispatcher != null && !Workmanager._inProcessDispatcherStarted) {
      Workmanager._inProcessDispatcherStarted = true;
      dispatcher();
    }
  }

  @override
  Future<BackgroundTaskResult> executeTask(
      String taskName, Map<String?, Object?>? inputData) async {
    final convertedInputData = convertPigeonInputData(inputData);
    final result = await Workmanager._backgroundTaskHandler
        ?.call(taskName, convertedInputData);
    return result ?? BackgroundTaskResult.retry;
  }

  @override
  Future<void> onTaskStopped(String taskName, int stopReason) async {
    final handler = Workmanager._onTaskStoppedHandler;
    if (handler != null) {
      await handler(taskName, StopReason.fromRawValue(stopReason));
    }
  }
}
