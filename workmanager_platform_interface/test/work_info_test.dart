import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

class _FakePlatform extends WorkmanagerPlatform {
  _FakePlatform(this.result);

  final WorkInfo? result;

  @override
  Future<WorkInfo?> getWorkInfo(String uniqueName) async => result;
}

class _UnimplementedPlatform extends WorkmanagerPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkInfo', () {
    test('fromData maps every field', () {
      final data = WorkInfoData(
        uniqueName: 'com.example.task',
        state: WorkState.succeeded,
        isPeriodic: true,
        taskName: 'dart-task',
        tags: <String?>['tag-a', 'tag-b'],
        lastFinishedAtMillis: 1700000000000,
      );

      final info = WorkInfo.fromData(data);

      expect(info.uniqueName, 'com.example.task');
      expect(info.state, WorkState.succeeded);
      expect(info.isPeriodic, true);
      expect(info.taskName, 'dart-task');
      expect(info.tags, <String>['tag-a', 'tag-b']);
      expect(info.lastFinishedAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    });

    test('fromData handles missing optional fields', () {
      final info = WorkInfo.fromData(WorkInfoData(
        uniqueName: 'u',
        state: WorkState.scheduled,
        isPeriodic: false,
      ));

      expect(info.taskName, isNull);
      expect(info.tags, isEmpty);
      expect(info.lastFinishedAt, isNull);
    });

    test('fromData drops null tags', () {
      final info = WorkInfo.fromData(WorkInfoData(
        uniqueName: 'u',
        state: WorkState.running,
        isPeriodic: false,
        tags: <String?>['a', null, 'b'],
      ));

      expect(info.tags, <String>['a', 'b']);
    });

    test('equality is value based', () {
      WorkInfo build() => WorkInfo(
            uniqueName: 'u',
            state: WorkState.failed,
            isPeriodic: false,
            taskName: 't',
            tags: const <String>['x'],
            lastFinishedAt: DateTime.fromMillisecondsSinceEpoch(123),
          );

      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build() == WorkInfo(uniqueName: 'other', state: WorkState.failed, isPeriodic: false), isFalse);
    });
  });

  group('WorkmanagerPlatform.getWorkInfo', () {
    test('delegates to the registered platform implementation', () async {
      final expected = WorkInfo(uniqueName: 'u', state: WorkState.cancelled, isPeriodic: false);
      WorkmanagerPlatform.instance = _FakePlatform(expected);

      final result = await WorkmanagerPlatform.instance.getWorkInfo('u');

      expect(result, expected);
    });

    test('default implementation throws UnimplementedError', () {
      WorkmanagerPlatform.instance = _UnimplementedPlatform();

      expect(
        () => WorkmanagerPlatform.instance.getWorkInfo('u'),
        throwsUnimplementedError,
      );
    });
  });
}
