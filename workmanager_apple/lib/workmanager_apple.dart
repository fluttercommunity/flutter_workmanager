import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

/// Apple (iOS/macOS) implementation of [WorkmanagerPlatform].
class WorkmanagerApple extends WorkmanagerPlatform {
  /// The method channel used to interact with the native platform.
  static const MethodChannel _channel = MethodChannel(
    'dev.fluttercommunity.workmanager/foreground_channel_work_manager',
  );

  /// Constructs a WorkmanagerApple instance.
  WorkmanagerApple() : super();

  /// Registers this class as the default instance of [WorkmanagerPlatform].
  static void registerWith() {
    WorkmanagerPlatform.instance = WorkmanagerApple();
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
      'initialDelaySeconds': initialDelay?.inSeconds,
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
    await _channel.invokeMethod('registerProcessingTask', {
      'uniqueName': uniqueName,
      'taskName': taskName,
      'inputData': inputData,
      'initialDelaySeconds': initialDelay?.inSeconds,
      'networkType': constraints?.networkType.name,
      'requiresCharging': constraints?.requiresCharging,
    });
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    await _channel.invokeMethod('cancelTaskByUniqueName', {
      'uniqueName': uniqueName,
    });
  }

  @override
  Future<void> cancelByTag(String tag) async {
    // Tags are not directly supported on iOS, so this is a no-op
    throw UnsupportedError('cancelByTag is not supported on iOS');
  }

  @override
  Future<void> cancelAll() async {
    await _channel.invokeMethod('cancelAllTasks');
  }

  @override
  Future<bool> isScheduledByUniqueName(String uniqueName) async {
    // This functionality is not available on iOS
    throw UnsupportedError('isScheduledByUniqueName is not supported on iOS');
  }

  @override
  Future<String> printScheduledTasks() async {
    final result = await _channel.invokeMethod<String>('printScheduledTasks');
    return result ?? 'No scheduled tasks information available';
  }
}
