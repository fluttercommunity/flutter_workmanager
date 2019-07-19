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

typedef TaskCallbackFunction = Future<bool> Function(String value);

void callbackDispatcher() {
  const MethodChannel _backgroundChannel =
      MethodChannel(_WorkmanagerConstants.backgroundChannelName);
  WidgetsFlutterBinding.ensureInitialized();
  _backgroundChannel.setMethodCallHandler(
      (call) => Workmanager.callBackFunction(call.arguments));
  _backgroundChannel.invokeMethod("backgroundChannelInitialized");
}

enum ExistingWorkPolicy { append, keep, replace }

enum NetworkType { connected, metered, not_required, not_roaming, unmetered }

enum BackoffPolicy { exponential, linear }

class Workmanager {
  static TaskCallbackFunction _callBackFunction;

  static TaskCallbackFunction get callBackFunction => _callBackFunction;

  static const MethodChannel _foregroundChannel = const MethodChannel(
      'be.tramckrijte.workmanager/foreground_channel_work_manager');

  static Future<void> initialize(
      final TaskCallbackFunction callBackFunction) async {
    assert(callBackFunction != null);
    Workmanager._callBackFunction = callBackFunction;
    final callback = PluginUtilities.getCallbackHandle(callbackDispatcher);
    await _foregroundChannel.invokeMethod(
      'initialize',
      {
        "callbackHandle": callback.toRawHandle(),
      },
    );
  }

  static Future<void> registerOneOffTask(
    final String uniqueName,
    final String valueToReturn, {
    final String tag,
    final ExistingWorkPolicy existingWorkPolicy,
    final double initialDelaySeconds = 0,
    final NetworkType networkType,
    final bool requiresBatteryNotLow,
    final bool requiresCharging,
    final bool requiresDeviceIdle,
    final bool requiresStorageNotLow,
    final BackoffPolicy backoffPolicy,
    final double backoffPolicyDelayMillis = 0,
  }) async =>
      await _register(
        methodName: "registerOneOffTask",
        uniqueName: uniqueName,
        valueToReturn: valueToReturn,
        tag: tag,
        existingWorkPolicy: existingWorkPolicy,
        initialDelaySeconds: initialDelaySeconds,
        networkType: networkType,
        requiresBatteryNotLow: requiresBatteryNotLow,
        requiresCharging: requiresCharging,
        requiresDeviceIdle: requiresDeviceIdle,
        requiresStorageNotLow: requiresStorageNotLow,
        backoffPolicy: backoffPolicy,
        backoffPolicyDelayMillis: backoffPolicyDelayMillis,
      );

  static Future<void> registerPeriodicTask(
    final String uniqueName,
    final String valueToReturn, {
    final double frequencySeconds = 0,
    final String tag,
    final ExistingWorkPolicy existingWorkPolicy,
    final double initialDelaySeconds = 0,
    final NetworkType networkType,
    final bool requiresBatteryNotLow,
    final bool requiresCharging,
    final bool requiresDeviceIdle,
    final bool requiresStorageNotLow,
    final BackoffPolicy backoffPolicy,
    final double backoffPolicyDelayMillis = 0,
  }) async =>
      await _register(
        methodName: "registerPeriodicTask",
        uniqueName: uniqueName,
        valueToReturn: valueToReturn,
        frequencySeconds: frequencySeconds,
        tag: tag,
        existingWorkPolicy: existingWorkPolicy,
        initialDelaySeconds: initialDelaySeconds,
        networkType: networkType,
        requiresBatteryNotLow: requiresBatteryNotLow,
        requiresCharging: requiresCharging,
        requiresDeviceIdle: requiresDeviceIdle,
        requiresStorageNotLow: requiresStorageNotLow,
        backoffPolicy: backoffPolicy,
        backoffPolicyDelayMillis: backoffPolicyDelayMillis,
      );

  static Future<void> _register({
    final String methodName,
    final String uniqueName,
    final String valueToReturn,
    final double frequencySeconds,
    final String tag,
    final ExistingWorkPolicy existingWorkPolicy,
    final double initialDelaySeconds,
    final NetworkType networkType,
    final bool requiresBatteryNotLow,
    final bool requiresCharging,
    final bool requiresDeviceIdle,
    final bool requiresStorageNotLow,
    final BackoffPolicy backoffPolicy,
    final double backoffPolicyDelayMillis,
  }) async {
    assert(uniqueName != null);
    assert(valueToReturn != null);
    return await _foregroundChannel.invokeMethod(
      methodName,
      {
        "uniqueName": uniqueName,
        "valueToReturn": valueToReturn,
        "tag": tag,
        "frequency": frequencySeconds,
        "existingWorkPolicy": existingWorkPolicy,
        "initialDelaySeconds": initialDelaySeconds,
        "networkType": networkType,
        "requiresBatteryNotLow": requiresBatteryNotLow,
        "requiresCharging": requiresCharging,
        "requiresDeviceIdle": requiresDeviceIdle,
        "requiresStorageNotLow": requiresStorageNotLow,
        "backoffPolicyType": backoffPolicy,
        "backoffDelayInMilliseconds": backoffPolicyDelayMillis,
      },
    );
  }

  static Future<void> cancelByUniqueName(final String uniqueName) async =>
      await _foregroundChannel
          .invokeMethod("cancelTaskByUniqueName", {"uniqueName": uniqueName});

  static Future<void> cancelByTag(final String tag) async =>
      await _foregroundChannel.invokeMethod("cancelTaskByTag", {"tag": tag});

  static Future<void> cancelAll() async =>
      await _foregroundChannel.invokeMethod("cancelAll");
}
