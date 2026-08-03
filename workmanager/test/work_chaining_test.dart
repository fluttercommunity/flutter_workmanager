import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';

/// Records [beginUniqueWork] calls made through [WorkmanagerPlatform] so the
/// facade can be verified without a real platform channel.
class _RecordingPlatform extends WorkmanagerPlatform {
  String? uniqueName;
  List<WorkChainTask>? tasks;
  ExistingWorkPolicy? existingWorkPolicy;

  @override
  Future<void> beginUniqueWork(
    String uniqueName, {
    required List<WorkChainTask> tasks,
    ExistingWorkPolicy? existingWorkPolicy,
  }) async {
    this.uniqueName = uniqueName;
    this.tasks = tasks;
    this.existingWorkPolicy = existingWorkPolicy;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkChainTask', () {
    test('exposes taskName and per-step configuration', () {
      final task = WorkChainTask(
        taskName: 'step1',
        inputData: {'url': 'https://example.com'},
        initialDelay: Duration(minutes: 5),
        tag: 'chain-tag',
      );

      expect(task.taskName, 'step1');
      expect(task.inputData, {'url': 'https://example.com'});
      expect(task.initialDelay, Duration(minutes: 5));
      expect(task.tag, 'chain-tag');
      expect(task.constraints, isNull);
      expect(task.backoffPolicy, isNull);
      expect(task.backoffPolicyDelay, isNull);
      expect(task.outOfQuotaPolicy, isNull);
      expect(task.foregroundServiceConfig, isNull);
    });

    test('per-step options default to null', () {
      final task = WorkChainTask(taskName: 'step1');

      expect(task.taskName, 'step1');
      expect(task.inputData, isNull);
      expect(task.initialDelay, isNull);
      expect(task.constraints, isNull);
      expect(task.backoffPolicy, isNull);
      expect(task.backoffPolicyDelay, isNull);
      expect(task.tag, isNull);
      expect(task.outOfQuotaPolicy, isNull);
      expect(task.foregroundServiceConfig, isNull);
    });
  });

  group('Workmanager.beginUniqueWork', () {
    late _RecordingPlatform platform;

    setUpAll(() {
      // Trigger the singleton construction once so _ensurePlatformImplementation
      // has already picked a platform implementation; the recording platform
      // below is then left untouched.
      Workmanager();
      platform = _RecordingPlatform();
      WorkmanagerPlatform.instance = platform;
    });

    test('rejects an empty task list', () async {
      await expectLater(
        () => Workmanager().beginUniqueWork('chain', tasks: []),
        throwsA(isA<ArgumentError>()),
      );
      // Nothing was forwarded to the platform.
      expect(platform.uniqueName, isNull);
    });

    test('forwards uniqueName, tasks and policy to the platform', () async {
      final tasks = [
        WorkChainTask(taskName: 'step1', inputData: {'step': 1}),
        WorkChainTask(taskName: 'step2', inputData: {'step': 2}),
      ];

      await Workmanager().beginUniqueWork(
        'chain-name',
        existingWorkPolicy: ExistingWorkPolicy.keep,
        tasks: tasks,
      );

      expect(platform.uniqueName, 'chain-name');
      expect(platform.tasks, same(tasks));
      expect(platform.existingWorkPolicy, ExistingWorkPolicy.keep);
    });

    test('existingWorkPolicy defaults to null (platform decides)', () async {
      await Workmanager().beginUniqueWork(
        'chain-name',
        tasks: [WorkChainTask(taskName: 'step1')],
      );

      expect(platform.uniqueName, 'chain-name');
      expect(platform.tasks, hasLength(1));
      expect(platform.tasks!.single.taskName, 'step1');
      expect(platform.existingWorkPolicy, isNull);
    });

    test('single-task chains are supported', () async {
      await Workmanager().beginUniqueWork(
        'single',
        tasks: [WorkChainTask(taskName: 'only-step')],
      );

      expect(platform.uniqueName, 'single');
      expect(platform.tasks, hasLength(1));
    });
  });
}
