import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

void main() {
  tearDown(WorkmanagerDebug.reset);

  test('default handler is a no-op', () {
    expect(WorkmanagerDebug.current, isA<WorkmanagerDebug>());
    // Must not throw.
    WorkmanagerDebug.reportStatus(
      _taskInfo(),
      TaskStatus.started,
      null,
    );
    WorkmanagerDebug.reportException(_taskInfo(), StateError('boom'), null);
  });

  test('setCurrent routes status updates to the handler', () {
    final events = <(TaskDebugInfo, TaskStatus, TaskResult?)>[];
    WorkmanagerDebug.setCurrent(_RecordingHandler(events));

    final taskInfo = _taskInfo();
    WorkmanagerDebug.reportStatus(taskInfo, TaskStatus.started, null);
    WorkmanagerDebug.reportStatus(
      taskInfo,
      TaskStatus.completed,
      TaskResult(success: true, duration: const Duration(milliseconds: 42)),
    );

    expect(events, hasLength(2));
    expect(events[0].$1.taskName, 'my-task');
    expect(events[0].$2, TaskStatus.started);
    expect(events[1].$2, TaskStatus.completed);
    expect(events[1].$3?.success, isTrue);
    expect(events[1].$3?.duration, const Duration(milliseconds: 42));
  });

  test('setCurrent routes exceptions to the handler', () {
    final exceptions = <Object>[];
    WorkmanagerDebug.setCurrent(
      _RecordingHandler(<(TaskDebugInfo, TaskStatus, TaskResult?)>[],
          exceptions: exceptions),
    );

    final error = StateError('boom');
    WorkmanagerDebug.reportException(_taskInfo(), error, null);

    expect(exceptions, [error]);
  });

  test('reset restores the no-op handler', () {
    WorkmanagerDebug.setCurrent(
      _RecordingHandler(<(TaskDebugInfo, TaskStatus, TaskResult?)>[]),
    );
    WorkmanagerDebug.reset();
    expect(WorkmanagerDebug.current, isA<WorkmanagerDebug>());
    // Must not throw with a cleared handler.
    WorkmanagerDebug.reportStatus(_taskInfo(), TaskStatus.failed, null);
  });

  test('LoggingDebugHandler does not throw on either callback', () {
    final handler = LoggingDebugHandler();
    handler.onTaskStatusUpdate(
      _taskInfo(),
      TaskStatus.failed,
      TaskResult(
        success: false,
        duration: const Duration(milliseconds: 500),
        error: 'nope',
      ),
    );
    handler.onExceptionEncountered(
      _taskInfo(),
      StateError('boom'),
      null,
    );
    expect(handler, isA<WorkmanagerDebug>());
  });
}

TaskDebugInfo _taskInfo() => TaskDebugInfo(
      taskName: 'my-task',
      uniqueName: 'my-unique',
      inputData: <String, dynamic>{'key': 'value'},
      startTime: DateTime(2026, 1, 1),
    );

class _RecordingHandler extends WorkmanagerDebug {
  _RecordingHandler(this.events, {List<Object>? exceptions})
      : exceptions = exceptions ?? <Object>[];

  final List<(TaskDebugInfo, TaskStatus, TaskResult?)> events;
  final List<Object> exceptions;

  @override
  void onTaskStatusUpdate(
    TaskDebugInfo taskInfo,
    TaskStatus status,
    TaskResult? result,
  ) {
    events.add((taskInfo, status, result));
  }

  @override
  void onExceptionEncountered(
    TaskDebugInfo? taskInfo,
    Object exception,
    StackTrace? stackTrace,
  ) {
    exceptions.add(exception);
  }
}
