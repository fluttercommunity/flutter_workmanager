import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';
import 'pigeon_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final logged = <String>[];
  final originalDebugPrint = debugPrint;

  setUp(() {
    WorkmanagerPlatform.instance = FakeApplePlatform();
    logged.clear();
    debugPrint = (message, {wrapWidth}) => logged.add(message ?? '');
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
  });

  test('task results: success round-trips; thrown exceptions become failure',
      () async {
    void callbackDispatcher() {
      Workmanager().executeTask((taskName, inputData) async {
        if (taskName == 'dev.fluttercommunity.test.boom') {
          throw StateError('task logic exploded');
        }
        return BackgroundTaskResult.success;
      });
    }

    await Workmanager().initialize(callbackDispatcher);

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    // Native side: initialize the channel, then execute the task.
    await sendPigeonMessage(
        messenger, '${pigeonChannelPrefix}backgroundChannelInitialized', null);

    // A returning handler surfaces the BackgroundTaskResult on the channel.
    final okReply = await sendPigeonMessage(
      messenger,
      '${pigeonChannelPrefix}executeTask',
      <Object?>['dev.fluttercommunity.test.ok', null],
    );
    expect(okReply, [BackgroundTaskResult.success]);

    // A thrown exception is caught by the plugin, logged, and reported as a
    // normal BackgroundTaskResult.failure — never a Pigeon channel error.
    // Native implementations map that to a permanent failure — Android
    // `Result.failure()`, iOS `.failed` — i.e. no retry.
    final boomReply = await sendPigeonMessage(
      messenger,
      '${pigeonChannelPrefix}executeTask',
      <Object?>['dev.fluttercommunity.test.boom', null],
    );
    expect(boomReply, [BackgroundTaskResult.failure]);

    // The exception is logged so it is debuggable without a console.
    expect(logged.join('\n'), contains('task logic exploded'));
  });
}
