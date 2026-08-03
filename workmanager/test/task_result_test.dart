import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';
import 'pigeon_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    WorkmanagerPlatform.instance = FakeApplePlatform();
  });

  test('task results: success value and thrown exceptions (no retry)',
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

    // A thrown exception surfaces as a Pigeon error reply (code 'error'), not
    // a BackgroundTaskResult. Native implementations map that to a permanent
    // failure — Android `Result.failure()`, iOS `.failed` — i.e. no retry.
    final boomReply = await sendPigeonMessage(
      messenger,
      '${pigeonChannelPrefix}executeTask',
      <Object?>['dev.fluttercommunity.test.boom', null],
    );
    expect(boomReply, isNotNull);
    final errorReply = boomReply as List<Object?>;
    expect(errorReply.length, 3);
    expect(errorReply[0], 'error');
    expect(errorReply[1], contains('task logic exploded'));
  });
}
