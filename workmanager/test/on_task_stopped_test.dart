import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';
import 'package:workmanager_apple/workmanager_apple.dart';

const String _channelPrefix =
    'dev.flutter.pigeon.workmanager_platform_interface.WorkmanagerFlutterApi.';

/// Fake platform that records initialize() calls without touching real
/// platform channels. Extends [WorkmanagerApple] so Workmanager's platform
/// auto-selection (which runs on macOS/iOS/Android hosts) does not replace it.
class _FakeApplePlatform extends WorkmanagerApple {
  @override
  Future<void> initialize(
    Function callbackDispatcher, {
    @Deprecated(
        'Use WorkmanagerDebug handlers instead. This parameter has no effect.')
    bool isInDebugMode = false,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    WorkmanagerPlatform.instance = _FakeApplePlatform();
  });

  Future<void> sendMessage(String channel, List<Object?>? message) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final codec = WorkmanagerFlutterApi.pigeonChannelCodec;
    ByteData? reply;
    await messenger.handlePlatformMessage(
      channel,
      codec.encodeMessage(message),
      (data) {
        reply = data;
      },
    );
    expect(reply, isNotNull);
    expect(codec.decodeMessage(reply) as List<Object?>?, isEmpty);
  }

  test('onTaskStopped notifies the registered handler with the stop reason',
      () async {
    final stopped = <(String, StopReason)>[];

    void callbackDispatcher() {
      Workmanager().executeTask(
        (taskName, inputData) async => BackgroundTaskResult.success,
        onTaskStopped: (taskName, stopReason) async {
          stopped.add((taskName, stopReason));
        },
      );
    }

    await Workmanager().initialize(callbackDispatcher);

    // Before the dispatcher has run, no handler is registered: the message is
    // acknowledged and nothing is delivered.
    await sendMessage('${_channelPrefix}onTaskStopped', <Object?>['task', 3]);
    expect(stopped, isEmpty);

    // Run the dispatcher so the stop handler is registered (the native side
    // does this via backgroundChannelInitialized before executing tasks).
    await sendMessage('${_channelPrefix}backgroundChannelInitialized', null);

    await sendMessage('${_channelPrefix}onTaskStopped',
        <Object?>['dev.fluttercommunity.test.sync', 3]);
    await sendMessage('${_channelPrefix}onTaskStopped', <Object?>['task', 99]);

    expect(stopped, [
      ('dev.fluttercommunity.test.sync', StopReason.cancelledByApp),
      ('task', StopReason.unknown),
    ]);
  });
}
