import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';
import 'package:workmanager_android/workmanager_android.dart';
import 'package:workmanager_apple/workmanager_apple.dart';

/// Function that executes your background work.
/// You should return whether the task ran successfully or not.
///
/// [taskName] Returns the value you provided when registering the task.
/// iOS will pass [Workmanager.iOSBackgroundTask] (for background-fetch) or
/// custom task IDs for BGTaskScheduler based tasks.
///
/// The behavior for retries is different on each platform:
/// - Android: return `false` from the this method will reschedule the work
///   based on the policy given in [Workmanager.registerOneOffTask], for example
/// - iOS: The return value is ignored, but if work has failed, you can schedule
///   another attempt using [Workmanager.registerOneOffTask]. This depends on
///   BGTaskScheduler being set up correctly. Please follow the README for
///   instructions.
typedef BackgroundTaskHandler = Future<bool> Function(
    String taskName, Map<String, dynamic>? inputData);

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
    if (WorkmanagerPlatform.instance is! WorkmanagerAndroid &&
        WorkmanagerPlatform.instance is! WorkmanagerIOS) {
      if (Platform.isAndroid) {
        WorkmanagerPlatform.instance = WorkmanagerAndroid();
      } else if (Platform.isIOS) {
        WorkmanagerPlatform.instance = WorkmanagerIOS();
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

  /// The method channel used to interact with the native platform.
  static const MethodChannel _backgroundChannel = MethodChannel(
      "dev.fluttercommunity.workmanager/background_channel_work_manager");

  static BackgroundTaskHandler? _backgroundTaskHandler;

  /// Platform implementation
  static WorkmanagerPlatform get _platform => WorkmanagerPlatform.instance;

  /// Initialize the Workmanager with a [callbackDispatcher].
  ///
  /// The [callbackDispatcher] is a top level function which will be invoked by Android or iOS whenever a scheduled task is due.
  /// The [isInDebugMode] will post local notifications for every background worker that ran. This is very useful when trying to debug what's happening in the background.
  Future<void> initialize(
    Function callbackDispatcher, {
    bool isInDebugMode = false,
  }) async {
    _backgroundChannel.setMethodCallHandler(_handleBackgroundMessage);
    return _platform.initialize(callbackDispatcher,
        isInDebugMode: isInDebugMode);
  }

  /// Handle background method calls from the platform
  Future<dynamic> _handleBackgroundMessage(MethodCall call) async {
    Map<String, dynamic>? inputData = call
        .arguments["dev.fluttercommunity.workmanager.INPUT_DATA"]
        .cast<String, dynamic>();

    if (call.method == "backgroundChannelInitialized") {
      return _backgroundTaskHandler?.call(
        call.arguments["dev.fluttercommunity.workmanager.DART_TASK"],
        inputData,
      );
    }
    return null;
  }

  /// This method needs to be called from within your [callbackDispatcher].
  ///
  /// [backgroundTaskHandler] is the callback that is provided when a background task is run.
  ///
  /// This is used by iOS and Android to identify which task was selected to run in the background.
  /// The [BackgroundTaskHandler] will provide you with the [taskName] and the [inputData].
  /// The [taskName] will always be the value you provided when registering the task.
  /// The [inputData] will contain all the data you registered the task with.
  ///
  /// You need to return a [Future<bool>] that will tell the OS if the task was successful or not.
  ///
  /// You can perfectly call other Flutter plugins inside this callback, as the callback is simply running within a Flutter background isolate.
  ///
  /// Scheduling other background tasks inside the [BackgroundTaskHandler] is allowed.
  void executeTask(BackgroundTaskHandler backgroundTaskHandler) async {
    WidgetsFlutterBinding.ensureInitialized();

    _backgroundChannel.setMethodCallHandler(_handleBackgroundMessage);
    _backgroundTaskHandler = backgroundTaskHandler;
    await _backgroundChannel.invokeMethod("backgroundChannelInitialized");
  }

  /// Schedule a one-off task.
  ///
  /// A [uniqueName] is required so only one task can be registered.
  ///
  /// Calling this method again with the same [uniqueName] will update the current pending task, unless an [ExistingWorkPolicy] is provided.
  ///
  /// - [taskName]: is the value that will be returned in the [BackgroundTaskHandler], ignored on iOS where you should use [uniqueName].
  /// - [inputData]: is the input data for task. Valid value types are: int, bool, double, String and their list
  /// - [initialDelay]: is an [Duration] after which the task will run. Ignored on iOS where you should schedule the task in AppDelegate.swift
  /// - [constraints]: are the requirements that need to be met before the task runs.
  /// - [backoffPolicy]: is the backoff policy to use when retrying work.
  /// - [backoffPolicyDelay]: is the delay for the backoff policy.
  /// - [tag]: is an optional tag that can be used to identify or cancel the task.
  /// - [existingWorkPolicy]: is the policy to use when work with the same [uniqueName] already exists.
  /// - [outOfQuotaPolicy]: is the policy to use when the device is out of quota. (Android only)
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
    );
  }

  /// Schedules a periodic task that will run every provided [frequency].
  ///
  /// On iOS it is not guaranteed when or how often it will run, iOS will schedule
  /// it as per user's App usage pattern, iOS might terminate the task or throttle
  /// it's frequency if it takes more than 30 seconds.
  ///
  /// A [uniqueName] is required so only one task can be registered.
  /// The [taskName] is the value that will be returned in the [BackgroundTaskHandler], ignored on iOS where you should use [uniqueName].
  /// a [frequency] is not required and will be defaulted to 15 minutes if not provided.
  /// a [frequency] has a minimum of 15 min. Android will automatically change your frequency to 15 min if you have configured a lower frequency.
  /// the [flexInterval] If the nature of the work is time-sensitive, you can configure the PeriodicWorkRequest to run in a flexible period at each interval.
  /// The [inputData] is the input data for task. Valid value types are: int, bool, double, String and their list
  ///
  /// Unlike Android, you cannot set [frequency] for iOS here rather you have to set in `AppDelegate.swift` while registering the task.
  /// The [inputData] is the input data for task. Valid value types are: int, bool, double, String and their list. It is not supported on iOS.
  ///
  /// For iOS see Apple docs:
  /// [iOS 13+ Using background tasks to update your app](https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background/using_background_tasks_to_update_your_app/)
  ///
  /// [iOS 13+ BGAppRefreshTask](https://developer.apple.com/documentation/backgroundtasks/bgapprefreshtask/)
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Duration? flexInterval,
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
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
