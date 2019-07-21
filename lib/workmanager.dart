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

class WorkManagerConstraintConfig {
  final NetworkType networkType;
  final bool requiresBatteryNotLow;
  final bool requiresCharging;
  final bool requiresDeviceIdle;
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

typedef EchoCallbackFunction = Future<bool> Function(String echoValue);

enum ExistingWorkPolicy { append, keep, replace }

enum NetworkType { connected, metered, not_required, not_roaming, unmetered }

enum BackoffPolicy { exponential, linear }

class Workmanager {
  static bool _isInDebugMode = false;

  static const MethodChannel _backgroundChannel =
      const MethodChannel(_WorkmanagerConstants.backgroundChannelName);
  static const MethodChannel _foregroundChannel =
      const MethodChannel(_WorkmanagerConstants.foregroundChannelName);

  static void defaultCallbackDispatcher(
      final EchoCallbackFunction echoFunction) {
    WidgetsFlutterBinding.ensureInitialized();
    _backgroundChannel
        .setMethodCallHandler((call) async => echoFunction(call.arguments));
    _backgroundChannel.invokeMethod("backgroundChannelInitialized");
  }

  static Future<void> initialize(
    final Function callbackDispatcher, {
    final bool isInDebugMode,
  }) async {
    Workmanager._isInDebugMode = isInDebugMode;
    final callback = PluginUtilities.getCallbackHandle(callbackDispatcher);
    await _foregroundChannel.invokeMethod('initialize', callback.toRawHandle());
  }

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

  static Future<void> registerPeriodicTask(
    final String uniqueName,
    final String echoValue, {
    final Duration frequency = _noDuration,
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

  static Future<void> cancelByUniqueName(final String uniqueName) async =>
      await _foregroundChannel
          .invokeMethod("cancelTaskByUniqueName", {"uniqueName": uniqueName});

  static Future<void> cancelByTag(final String tag) async =>
      await _foregroundChannel.invokeMethod("cancelTaskByTag", {"tag": tag});

  static Future<void> cancelAll() async =>
      await _foregroundChannel.invokeMethod("cancelAll");
}
