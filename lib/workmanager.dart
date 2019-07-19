import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

void callbackDispatcher() {
  print("Method invoked by native code");
  const MethodChannel _backgroundChannel = MethodChannel(
      'be.tramckrijte.workmanager/background_channel_work_manager');
  WidgetsFlutterBinding.ensureInitialized();
  _backgroundChannel.setMethodCallHandler((MethodCall call) {
    final args = call.arguments;
    print("Calling from native: $args");
    return Future.value(true);
  });

  _backgroundChannel.invokeMethod("backgroundChannelInitialized");
}

class Workmanager {
  static const MethodChannel _foregroundChannel = const MethodChannel(
      'be.tramckrijte.workmanager/foreground_channel_work_manager');

  static Future<void> initialize() async {
    final callback = PluginUtilities.getCallbackHandle(callbackDispatcher);
    await _foregroundChannel.invokeMethod(
      'initialize',
      {"callbackHandle": callback.toRawHandle()},
    );
  }

  static Future<void> registerSampleTask(final String uniqueName, final String valueToReturn) async {
    await _foregroundChannel.invokeMethod(
      'registerOneOffTask',
      {"uniqueName": uniqueName, "valueToReturn": valueToReturn},
    );
  }
}
