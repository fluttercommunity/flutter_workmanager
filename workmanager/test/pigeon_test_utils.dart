import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';
import 'package:workmanager_apple/workmanager_apple.dart';

/// Prefix of the Pigeon channel names generated for WorkmanagerFlutterApi.
const String pigeonChannelPrefix =
    'dev.flutter.pigeon.workmanager_platform_interface.WorkmanagerFlutterApi.';

/// Fake platform that records initialize() calls without touching real
/// platform channels. Extends [WorkmanagerApple] so Workmanager's platform
/// auto-selection (which runs on macOS/iOS/Android hosts) does not replace it.
class FakeApplePlatform extends WorkmanagerApple {
  Function? lastCallbackDispatcher;

  @override
  Future<void> initialize(
    Function callbackDispatcher, {
    @Deprecated(
        'Use WorkmanagerDebug handlers instead. This parameter has no effect.')
    bool isInDebugMode = false,
  }) async {
    lastCallbackDispatcher = callbackDispatcher;
  }
}

/// Sends a Pigeon message on [messenger] and returns the decoded reply.
///
/// The Workmanager statics (registered dispatcher, handler) are per-isolate,
/// so tests that register different handlers must live in separate test files
/// (each file runs in its own isolate).
Future<List<Object?>?> sendPigeonMessage(
  TestDefaultBinaryMessenger messenger,
  String channel,
  Object? message,
) async {
  ByteData? reply;
  await messenger.handlePlatformMessage(
    channel,
    WorkmanagerFlutterApi.pigeonChannelCodec.encodeMessage(message),
    (data) {
      reply = data;
    },
  );
  return reply == null
      ? null
      : WorkmanagerFlutterApi.pigeonChannelCodec.decodeMessage(reply)
          as List<Object?>?;
}
