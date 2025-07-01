import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

/// Android implementation of [WorkmanagerPlatform].
class WorkmanagerAndroid extends WorkmanagerPlatform {
  /// The method channel used to interact with the native platform.
  static const MethodChannel _channel = MethodChannel(
    'dev.fluttercommunity.workmanager/foreground_channel_work_manager',
  );

  /// Constructs an AndroidWorkmanager.
  WorkmanagerAndroid() : super();

  /// Registers this class as the default instance of [WorkmanagerPlatform].
  static void registerWith() {
    WorkmanagerPlatform.instance = WorkmanagerAndroid();
  }

  @override
  Future<void> initialize(
    Function callbackDispatcher, {
    bool isInDebugMode = false,
  }) async {
    final callback = PluginUtilities.getCallbackHandle(callbackDispatcher);
    await _channel.invokeMethod('initialize', {
      'callbackHandle': callback!.toRawHandle(),
      'isInDebugMode': isInDebugMode,
    });
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
  }) async {
    await _channel.invokeMethod('registerOneOffTask', {
      'uniqueName': uniqueName,
      'taskName': taskName,
      'inputData': inputData,
      'initialDelaySeconds': initialDelay?.inSeconds,
      'networkType': constraints?.networkType?.name,
      'requiresBatteryNotLow': constraints?.requiresBatteryNotLow,
      'requiresCharging': constraints?.requiresCharging,
      'requiresDeviceIdle': constraints?.requiresDeviceIdle,
      'requiresStorageNotLow': constraints?.requiresStorageNotLow,
      'existingWorkPolicy': existingWorkPolicy?.name,
      'backoffPolicy': backoffPolicy?.name,
      'backoffDelayInMilliseconds': backoffPolicyDelay?.inMilliseconds,
      'tag': tag,
      'outOfQuotaPolicy': outOfQuotaPolicy?.name,
    });
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
    ExistingWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
  }) async {
    await _channel.invokeMethod('registerPeriodicTask', {
      'uniqueName': uniqueName,
      'taskName': taskName,
      'inputData': inputData,
      'frequencySeconds': frequency?.inSeconds,
      'flexIntervalSeconds': flexInterval?.inSeconds,
      'initialDelaySeconds': initialDelay?.inSeconds,
      'networkType': constraints?.networkType?.name,
      'requiresBatteryNotLow': constraints?.requiresBatteryNotLow,
      'requiresCharging': constraints?.requiresCharging,
      'requiresDeviceIdle': constraints?.requiresDeviceIdle,
      'requiresStorageNotLow': constraints?.requiresStorageNotLow,
      'existingWorkPolicy': existingWorkPolicy?.name,
      'backoffPolicy': backoffPolicy?.name,
      'backoffDelayInMilliseconds': backoffPolicyDelay?.inMilliseconds,
      'tag': tag,
    });
  }

  @override
  Future<void> registerProcessingTask(
    String uniqueName,
    String taskName, {
    Duration? initialDelay,
    Map<String, dynamic>? inputData,
    Constraints? constraints,
  }) async {
    // Processing tasks are iOS-specific, so this is a no-op on Android
    throw UnsupportedError('Processing tasks are not supported on Android');
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    await _channel.invokeMethod('cancelTaskByUniqueName', {
      'uniqueName': uniqueName,
    });
  }

  @override
  Future<void> cancelByTag(String tag) async {
    await _channel.invokeMethod('cancelTaskByTag', {
      'tag': tag,
    });
  }

  @override
  Future<void> cancelAll() async {
    await _channel.invokeMethod('cancelAllTasks');
  }

  @override
  Future<bool> isScheduledByUniqueName(String uniqueName) async {
    final result =
        await _channel.invokeMethod<bool>('isScheduledByUniqueName', {
      'uniqueName': uniqueName,
    });
    return result ?? false;
  }

  @override
  Future<String> printScheduledTasks() async {
    throw UnsupportedError('printScheduledTasks is not supported on Android');
  }
}
