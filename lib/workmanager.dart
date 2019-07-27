import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class _WorkmanagerConstants {
  static const backgroundChannelName =
      "be.tramckrijte.workmanager/background_channel_work_manager";
  static const foregroundChannelName =
      "be.tramckrijte.workmanager/foreground_channel_work_manager";
}

///A specification of the requirements that need to be met before a WorkRequest can run.
///By default, WorkRequests do not have any requirements and can run immediately.
///By adding requirements, you can make sure that work only runs in certain situations -
///for example, when you have an unmetered network and are charging.
class WorkManagerConstraintConfig {
  ///An enumeration of various network types that can be used as Constraints for work.
  final NetworkType networkType;

  ///true if the work should only execute when the battery isn't low
  final bool requiresBatteryNotLow;

  ///true if the work should only execute while the device is charging
  final bool requiresCharging;

  ///true if the work should only execute while the device is idle
  final bool requiresDeviceIdle;

  ///true if the work should only execute when the storage isn't low
  final bool requiresStorageNotLow;

  WorkManagerConstraintConfig({
    this.networkType,
    this.requiresBatteryNotLow,
    this.requiresCharging,
    this.requiresDeviceIdle,
    this.requiresStorageNotLow,
  });
}

const _noDuration = const Duration(seconds: 0);

/// Returns the echo value provided when registering the task.
typedef EchoCallbackFunction = Future<bool> Function(String echoValue);

///An enumeration of the conflict resolution policies in case of a collision.
enum ExistingWorkPolicy {
  ///If there is existing pending (uncompleted) work with the same unique name, append the newly-specified work as a child of all the leaves of that work sequence.
  append,

  ///If there is existing pending (uncompleted) work with the same unique name, do nothing.
  keep,

  ///If there is existing pending (uncompleted) work with the same unique name, cancel and delete it.
  replace
}

/// An enumeration of various network types that can be used as Constraints for work.
enum NetworkType {
  ///Any working network connection is required for this work.
  connected,

  ///A metered network connection is required for this work.
  metered,

  ///Default value. A network is not required for this work.
  not_required,

  ///A non-roaming network connection is required for this work.
  not_roaming,

  ///An unmetered network connection is required for this work.
  unmetered,
}

///An enumeration of backoff policies when retrying work.
///These policies are used when you have a return ListenableWorker.Result.retry() from a worker to determine the correct backoff time.
///Backoff policies are set in WorkRequest.Builder.setBackoffCriteria(BackoffPolicy, long, TimeUnit) or one of its variants.
enum BackoffPolicy {
  ///Used to indicate that WorkManager should increase the backoff time exponentially
  exponential,

  ///Used to indicate that WorkManager should increase the backoff time linearly
  linear
}

class Workmanager {
  static bool _isInDebugMode = false;

  static const MethodChannel _backgroundChannel =
      const MethodChannel(_WorkmanagerConstants.backgroundChannelName);
  static const MethodChannel _foregroundChannel =
      const MethodChannel(_WorkmanagerConstants.foregroundChannelName);

  /// A helper function so you only need to implement a [EchoCallbackFunction]
  static void defaultCallbackDispatcher(
      final EchoCallbackFunction echoFunction) {
    WidgetsFlutterBinding.ensureInitialized();
    _backgroundChannel
        .setMethodCallHandler((call) async => echoFunction(call.arguments));
    _backgroundChannel.invokeMethod("backgroundChannelInitialized");
  }

  /// Optional initializer of the WorkManager plugin.
  /// callbackDispatcher is a top level function which will be invoked. Default the plugin will look for a top level method inside your main file called callbackDispatcher. If you wish to override this behaviour you can pass in your own.
  /// isInDebugMode true will post debug notifications (on Android) with information about when a job should have run
  static Future<void> initialize({
    final Function callbackDispatcher,
    final bool isInDebugMode,
  }) async {
    Workmanager._isInDebugMode = isInDebugMode;
    final callbackHandle = callbackDispatcher != null ? PluginUtilities.getCallbackHandle(callbackDispatcher).toRawHandle() : -1;
    await _foregroundChannel.invokeMethod('initialize', callbackHandle);
  }

  /// Schedule a one off task
  /// A unique name is required so only one job can be registered.
  /// The echoValue is the value that will be returned in the [EchoCallbackFunction]
  static Future<void> registerOneOffTask(
    final String uniqueName,
    final String echoValue, {
    final String tag,
    final ExistingWorkPolicy existingWorkPolicy,
    final Duration initialDelay = _noDuration,
    final WorkManagerConstraintConfig constraints,
    final BackoffPolicy backoffPolicy,
    final Duration backoffPolicyDelay = _noDuration,
  }) async =>
      await _register(
        methodName: "registerOneOffTask",
        uniqueName: uniqueName,
        echoValue: echoValue,
        tag: tag,
        existingWorkPolicy: existingWorkPolicy,
        initialDelay: initialDelay,
        constraints: constraints,
        backoffPolicy: backoffPolicy,
        backoffPolicyDelay: backoffPolicyDelay,
      );

  /// Schedules a periodic task that will run every provided [frequency].
  /// A unique name is required so only one job can be registered.
  /// The echoValue is the value that will be returned in the [EchoCallbackFunction]
  /// a frequency is not required and will be defaulted to 15 minutes if not provided.
  static Future<void> registerPeriodicTask(
    final String uniqueName,
    final String echoValue, {
    final Duration frequency,
    final String tag,
    final ExistingWorkPolicy existingWorkPolicy,
    final Duration initialDelay = _noDuration,
    final WorkManagerConstraintConfig constraints,
    final BackoffPolicy backoffPolicy,
    final Duration backoffPolicyDelay = _noDuration,
  }) async =>
      await _register(
        methodName: "registerPeriodicTask",
        uniqueName: uniqueName,
        echoValue: echoValue,
        frequency: frequency,
        tag: tag,
        existingWorkPolicy: existingWorkPolicy,
        initialDelay: initialDelay,
        constraints: constraints,
        backoffPolicy: backoffPolicy,
        backoffPolicyDelay: backoffPolicyDelay,
      );

  static Future<void> _register({
    final String methodName,
    final String uniqueName,
    final String echoValue,
    final Duration frequency,
    final String tag,
    final ExistingWorkPolicy existingWorkPolicy,
    final Duration initialDelay,
    final WorkManagerConstraintConfig constraints,
    final BackoffPolicy backoffPolicy,
    final Duration backoffPolicyDelay,
  }) async {
    assert(uniqueName != null);
    assert(echoValue != null);
    return await _foregroundChannel.invokeMethod(
      methodName,
      {
        "isInDebugMode": _isInDebugMode,
        "uniqueName": uniqueName,
        "echoValue": echoValue,
        "tag": tag,
        "frequency": frequency?.inSeconds,
        "existingWorkPolicy": existingWorkPolicy,
        "initialDelaySeconds": initialDelay.inSeconds,
        "networkType": constraints?.networkType,
        "requiresBatteryNotLow": constraints?.requiresBatteryNotLow,
        "requiresCharging": constraints?.requiresCharging,
        "requiresDeviceIdle": constraints?.requiresDeviceIdle,
        "requiresStorageNotLow": constraints?.requiresStorageNotLow,
        "backoffPolicyType": backoffPolicy,
        "backoffDelayInMilliseconds": backoffPolicyDelay.inMilliseconds,
      },
    );
  }

  /// Cancels a job by its unique name
  static Future<void> cancelByUniqueName(final String uniqueName) async =>
      await _foregroundChannel
          .invokeMethod("cancelTaskByUniqueName", {"uniqueName": uniqueName});

  /// Cancels a job by its tag
  static Future<void> cancelByTag(final String tag) async =>
      await _foregroundChannel.invokeMethod("cancelTaskByTag", {"tag": tag});

  /// Cancels all jobs
  static Future<void> cancelAll() async =>
      await _foregroundChannel.invokeMethod("cancelAll");
}
