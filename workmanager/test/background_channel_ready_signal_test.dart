import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';
import 'package:workmanager_apple/workmanager_apple.dart';

/// Host channel the Dart side uses to signal that its task handlers are
/// registered. Native workers wait for this signal before invoking
/// [WorkmanagerFlutterApi.executeTask], so the handshake never races isolate
/// startup (regression introduced by the Pigeon migration — see #732/#738).
const String _readyChannel =
    'dev.flutter.pigeon.workmanager_platform_interface.WorkmanagerHostApi'
    '.notifyBackgroundChannelInitialized';

/// Fake platform that records initialize() calls without touching real
/// platform channels. Extends [WorkmanagerApple] so Workmanager's platform
/// auto-selection does not replace it on the test host.
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

  test('executeTask signals readiness and does not wait for the reply',
      () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final codec = WorkmanagerFlutterApi.pigeonChannelCodec;

    var readySignals = 0;
    // Simulate a native side that receives the signal but never answers (the
    // case on platforms without a native receiver, e.g. desktop headless).
    // Recording the invocation is enough; the worker must not depend on the
    // reply.
    final never = Completer<ByteData?>();
    messenger.setMockMessageHandler(_readyChannel, (ByteData? message) {
      readySignals++;
      expect(message, isNull);
      return never.future;
    });

    final executedTasks = <String>[];
    void callbackDispatcher() {
      Workmanager().executeTask((taskName, inputData) async {
        executedTasks.add(taskName);
        return true;
      });
    }

    await Workmanager().initialize(callbackDispatcher);
    expect(readySignals, 0,
        reason: 'no signal may be sent before a task executes');

    callbackDispatcher();

    // Exactly one readiness signal per executeTask call, sent after the task
    // handler was registered (setUp runs before the signal in executeTask).
    expect(readySignals, 1);

    // The task handler must still be executable while the signal is
    // unanswered: simulate the native side invoking executeTask once the
    // signal was sent.
    ByteData? reply;
    await messenger.handlePlatformMessage(
      'dev.flutter.pigeon.workmanager_platform_interface.WorkmanagerFlutterApi'
      '.executeTask',
      codec.encodeMessage(<Object?>[
        'dev.fluttercommunity.test.oneOff',
        <String?, Object?>{'foo': 'bar'},
      ]),
      (data) {
        reply = data;
      },
    );
    expect(reply, isNotNull);
    expect(codec.decodeMessage(reply), [true]);
    expect(executedTasks, ['dev.fluttercommunity.test.oneOff']);
  });
}
