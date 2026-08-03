// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';
import 'package:workmanager_linux/execution.dart';
import 'package:workmanager_linux/src/background_runner.dart';

void main() {
  group('BackgroundTaskInvocation.tryParse', () {
    test('returns null without --background-task', () {
      expect(BackgroundTaskInvocation.tryParse(<String>[]), isNull);
      expect(
          BackgroundTaskInvocation.tryParse(<String>['--foo', 'bar']), isNull);
    });

    test('returns null when the task name is missing', () {
      expect(BackgroundTaskInvocation.tryParse(<String>['--background-task']),
          isNull);
    });

    test('parses the task name', () {
      final invocation = BackgroundTaskInvocation.tryParse(
          <String>['--background-task', 'sync']);
      expect(invocation, isNotNull);
      expect(invocation!.taskName, 'sync');
      expect(invocation.payloadPath, isNull);
    });

    test('parses the payload path', () {
      final invocation = BackgroundTaskInvocation.tryParse(<String>[
        '--background-task',
        'sync',
        '--payload',
        '/tmp/workmanager-1234abcd.json',
      ]);
      expect(invocation, isNotNull);
      expect(invocation!.taskName, 'sync');
      expect(invocation.payloadPath, '/tmp/workmanager-1234abcd.json');
    });

    test('ignores unrelated leading arguments', () {
      final invocation = BackgroundTaskInvocation.tryParse(<String>[
        '/opt/app/example',
        '--background-task',
        'sync',
        '--payload',
        '/tmp/payload.json',
      ]);
      expect(invocation, isNotNull);
      expect(invocation!.taskName, 'sync');
      expect(invocation.payloadPath, '/tmp/payload.json');
    });
  });

  group('BackgroundTaskRunner', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('wm-runner-test-');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('runs the dispatcher and invokes the registered handler', () async {
      final payloadPath = '${tempDir.path}/payload.json';
      File(payloadPath).writeAsStringSync('{"key": "value", "n": 42}');

      var dispatcherRuns = 0;
      String? seenTaskName;
      Map<String, dynamic>? seenData;

      WorkmanagerExecution.instance.taskHandler = (taskName, inputData) async {
        seenTaskName = taskName;
        seenData = inputData;
        return true;
      };
      addTearDown(() => WorkmanagerExecution.instance.taskHandler = null);

      final runner = BackgroundTaskRunner();
      final result = await runner.run(
        BackgroundTaskInvocation(
          taskName: 'sync',
          payloadPath: payloadPath,
        ),
        () {
          dispatcherRuns++;
        },
      );

      expect(dispatcherRuns, 1);
      expect(seenTaskName, 'sync');
      expect(seenData, <String, dynamic>{'key': 'value', 'n': 42});
      expect(result, isTrue);
    });

    test('passes null input data when no payload was written', () async {
      Object? seenData = 'unset';
      WorkmanagerExecution.instance.taskHandler = (taskName, inputData) async {
        seenData = inputData;
        return true;
      };
      addTearDown(() => WorkmanagerExecution.instance.taskHandler = null);

      final result = await BackgroundTaskRunner().run(
        const BackgroundTaskInvocation(taskName: 'sync'),
        () {},
      );

      expect(seenData, isNull);
      expect(result, isTrue);
    });

    test('returns false when no handler is registered', () async {
      WorkmanagerExecution.instance.taskHandler = null;
      final result = await BackgroundTaskRunner().run(
        const BackgroundTaskInvocation(taskName: 'sync'),
        () {},
      );
      expect(result, isFalse);
    });

    test('returns false when the handler throws', () async {
      WorkmanagerExecution.instance.taskHandler = (taskName, inputData) async {
        throw StateError('boom');
      };
      addTearDown(() => WorkmanagerExecution.instance.taskHandler = null);

      final result = await BackgroundTaskRunner().run(
        const BackgroundTaskInvocation(taskName: 'sync'),
        () {},
      );
      expect(result, isFalse);
    });

    test('returns false when the dispatcher throws synchronously', () async {
      WorkmanagerExecution.instance.taskHandler = null;
      final result = await BackgroundTaskRunner().run(
        const BackgroundTaskInvocation(taskName: 'sync'),
        () => throw StateError('bad dispatcher'),
      );
      expect(result, isFalse);
    });
  });
}
