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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    WorkmanagerPlatform.instance = _FakeApplePlatform();
  });

  test(
      'one-off tasks execute on the main engine without a second Flutter engine',
      () async {
    final executedTasks = <String>[];
    var dispatcherRuns = 0;

    void callbackDispatcher() {
      dispatcherRuns++;
      Workmanager().executeTask((taskName, inputData) async {
        executedTasks.add(taskName);
        return BackgroundTaskResult.success;
      });
    }

    await Workmanager().initialize(callbackDispatcher);

    // The dispatcher must not run at initialize time; it runs lazily on the
    // first in-process task.
    expect(dispatcherRuns, 0);

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final codec = WorkmanagerFlutterApi.pigeonChannelCodec;

    Future<List<Object?>?> send(String channel, Object? message) async {
      ByteData? reply;
      await messenger.handlePlatformMessage(
        channel,
        codec.encodeMessage(message),
        (data) {
          reply = data;
        },
      );
      return reply == null
          ? null
          : codec.decodeMessage(reply) as List<Object?>?;
    }

    // Simulate the native side executing a one-off task on the running
    // (main) engine: backgroundChannelInitialized, then executeTask.
    final initReply =
        await send('${_channelPrefix}backgroundChannelInitialized', null);
    expect(initReply, isEmpty);
    expect(dispatcherRuns, 1);

    final taskReply = await send(
      '${_channelPrefix}executeTask',
      <Object?>[
        'dev.fluttercommunity.test.oneOff',
        <String?, Object?>{'foo': 'bar'},
      ],
    );
    expect(taskReply, [BackgroundTaskResult.success]);
    expect(executedTasks, ['dev.fluttercommunity.test.oneOff']);

    // A second task must not run the dispatcher again.
    await send('${_channelPrefix}backgroundChannelInitialized', null);
    await send(
      '${_channelPrefix}executeTask',
      <Object?>['dev.fluttercommunity.test.oneOff.two', null],
    );
    expect(dispatcherRuns, 1);
    expect(executedTasks, [
      'dev.fluttercommunity.test.oneOff',
      'dev.fluttercommunity.test.oneOff.two',
    ]);
  });
}
