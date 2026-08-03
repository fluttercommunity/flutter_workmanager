import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';
import 'pigeon_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    WorkmanagerPlatform.instance = FakeApplePlatform();
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

    // Simulate the native side executing a one-off task on the running
    // (main) engine: backgroundChannelInitialized, then executeTask.
    final initReply = await sendPigeonMessage(
        messenger, '${pigeonChannelPrefix}backgroundChannelInitialized', null);
    expect(initReply, isEmpty);
    expect(dispatcherRuns, 1);

    final taskReply = await sendPigeonMessage(
      messenger,
      '${pigeonChannelPrefix}executeTask',
      <Object?>[
        'dev.fluttercommunity.test.oneOff',
        <String?, Object?>{'foo': 'bar'},
      ],
    );
    expect(taskReply, [BackgroundTaskResult.success]);
    expect(executedTasks, ['dev.fluttercommunity.test.oneOff']);

    // A second task must not run the dispatcher again.
    await sendPigeonMessage(
        messenger, '${pigeonChannelPrefix}backgroundChannelInitialized', null);
    await sendPigeonMessage(
      messenger,
      '${pigeonChannelPrefix}executeTask',
      <Object?>['dev.fluttercommunity.test.oneOff.two', null],
    );
    expect(dispatcherRuns, 1);
    expect(executedTasks, [
      'dev.fluttercommunity.test.oneOff',
      'dev.fluttercommunity.test.oneOff.two',
    ]);
  });
}
