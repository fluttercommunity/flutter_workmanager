// Copyright 2026 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager_windows/src/payload_store.dart';
import 'package:workmanager_windows/src/process_runner.dart';
import 'package:workmanager_windows/workmanager_windows.dart';

/// Records `schtasks` invocations and returns canned results, so the platform
/// implementation is testable without a Windows shell.
class FakeProcessRunner implements ProcessRunner {
  final List<List<String>> calls = <List<String>>[];
  final List<FakeProcessResult> queuedResults = <FakeProcessResult>[];

  int exitCode = 0;
  String stdout = '';
  String stderr = '';

  @override
  Future<ProcessResult> run(String executable, List<String> arguments) async {
    calls.add(arguments);
    final queued = queuedResults.isEmpty ? null : queuedResults.removeAt(0);
    return ProcessResult(
      0,
      queued?.exitCode ?? exitCode,
      queued?.stdout ?? stdout,
      queued?.stderr ?? stderr,
    );
  }
}

class FakeProcessResult {
  FakeProcessResult({this.exitCode = 0, this.stdout = '', this.stderr = ''});

  final int exitCode;
  final String stdout;
  final String stderr;
}

void main() {
  late Directory tempDir;
  late FakeProcessRunner runner;
  late WorkmanagerWindows windows;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wm_windows_platform_');
    runner = FakeProcessRunner();
    windows = WorkmanagerWindows(
      processRunner: runner,
      payloadDirectory: Directory(
        '${tempDir.path}${Platform.pathSeparator}payloads',
      ),
    );
    WorkmanagerExecution.instance.taskHandler = null;
    WorkmanagerExecution.instance.callbackDispatcher = null;
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('registration', () {
    test(
      'registerOneOffTask creates a /SC ONCE task with payload and action',
      () async {
        await windows.registerOneOffTask(
          'demo',
          'demoTask',
          inputData: <String, dynamic>{'key': 'value'},
          initialDelay: const Duration(minutes: 5),
        );

        expect(runner.calls, hasLength(1));
        final args = runner.calls.single;
        expect(args.sublist(0, 5), <String>[
          '/Create',
          '/TN',
          'workmanager_demo',
          '/TR',
          '"${Platform.resolvedExecutable}" --background-task "demoTask" '
              '--payload-file "${tempDir.path}${Platform.pathSeparator}'
              'payloads${Platform.pathSeparator}demo.json"',
        ]);
        expect(args, containsAllInOrder(<String>['/SC', 'ONCE']));
        expect(args, contains('/SD'));
        expect(args, contains('/ST'));
        expect(args, contains('/F'));

        // The payload file was persisted and round-trips.
        final store = PayloadStore(
          Directory('${tempDir.path}${Platform.pathSeparator}payloads'),
        );
        expect(await store.read('demo'), <String, dynamic>{'key': 'value'});
      },
    );

    test(
      'registerOneOffTask without inputData passes no --payload-file',
      () async {
        await windows.registerOneOffTask('demo', 'demoTask');
        final args = runner.calls.single;
        final action = args[args.indexOf('/TR') + 1];
        expect(action, isNot(contains('--payload-file')));
        expect(
          PayloadStore(
            Directory('${tempDir.path}${Platform.pathSeparator}payloads'),
          ).fileFor('demo').existsSync(),
          isFalse,
        );
      },
    );

    test(
      'registerOneOffTask rolls the payload back when schtasks fails',
      () async {
        runner.exitCode = 2;
        runner.stderr = 'ERROR: Access is denied.';
        await expectLater(
          windows.registerOneOffTask('demo', 'demoTask'),
          throwsStateError,
        );
        expect(
          PayloadStore(
            Directory('${tempDir.path}${Platform.pathSeparator}payloads'),
          ).fileFor('demo').existsSync(),
          isFalse,
        );
      },
    );

    test('registerOneOffTask rejects non-JSON-encodable inputData', () async {
      await expectLater(
        windows.registerOneOffTask(
          'demo',
          'demoTask',
          inputData: <String, dynamic>{'obj': Object()},
        ),
        throwsArgumentError,
      );
      expect(runner.calls, isEmpty);
    });

    test('registerPeriodicTask creates a /SC DAILY task with /RI', () async {
      await windows.registerPeriodicTask(
        'sync',
        'syncTask',
        frequency: const Duration(minutes: 30),
      );
      final args = runner.calls.single;
      expect(args.sublist(0, 4), <String>[
        '/Create',
        '/TN',
        'workmanager_sync',
        '/TR',
      ]);
      expect(args, containsAllInOrder(<String>['/SC', 'DAILY']));
      expect(args, containsAllInOrder(<String>['/RI', '30']));
    });

    test('registerPeriodicTask defaults the frequency to 15 minutes', () async {
      await windows.registerPeriodicTask('sync', 'syncTask');
      final args = runner.calls.single;
      expect(args, containsAllInOrder(<String>['/RI', '15']));
    });
  });

  group('cancellation', () {
    test(
      'cancelByUniqueName ends and deletes the task and its payload',
      () async {
        await windows.registerOneOffTask(
          'demo',
          'demoTask',
          inputData: <String, dynamic>{'key': 'value'},
        );
        runner.calls.clear();
        final payloadFile = PayloadStore(
          Directory('${tempDir.path}${Platform.pathSeparator}payloads'),
        ).fileFor('demo');
        expect(payloadFile.existsSync(), isTrue);

        await windows.cancelByUniqueName('demo');

        expect(runner.calls, hasLength(2));
        expect(runner.calls[0], <String>['/End', '/TN', 'workmanager_demo']);
        expect(runner.calls[1], <String>[
          '/Delete',
          '/TN',
          'workmanager_demo',
          '/F',
        ]);
        expect(payloadFile.existsSync(), isFalse);
      },
    );

    test('cancelByUniqueName is idempotent for a missing task', () async {
      runner.exitCode = 1;
      runner.stderr = 'ERROR: The system cannot find the file specified.';
      await windows.cancelByUniqueName('demo');
    });

    test('cancelByUniqueName throws on unexpected schtasks failures', () async {
      runner.exitCode = 5;
      runner.stderr = 'ERROR: something else.';
      await expectLater(windows.cancelByUniqueName('demo'), throwsStateError);
    });

    test('cancelAll deletes only owned tasks and clears payloads', () async {
      await windows.registerOneOffTask(
        'one',
        'oneTask',
        inputData: <String, dynamic>{'k': 1},
      );
      await windows.registerOneOffTask(
        'two',
        'twoTask',
        inputData: <String, dynamic>{'k': 2},
      );
      final store = PayloadStore(
        Directory('${tempDir.path}${Platform.pathSeparator}payloads'),
      );
      expect(await store.read('one'), isNotNull);
      expect(await store.read('two'), isNotNull);

      runner.calls.clear();
      runner.stdout = '"workmanager_one","8/3/2026 11:15:00 AM","Ready"\n'
          '"workmanager_two","8/4/2026 9:00:00 AM","Ready"\n'
          '"SomeOtherTask","N/A","Disabled"';
      await windows.cancelAll();

      // One query plus /End and /Delete for each of the two owned tasks.
      expect(runner.calls, hasLength(5));
      expect(runner.calls[0], <String>['/Query', '/FO', 'CSV', '/NH']);
      expect(runner.calls[1], <String>['/End', '/TN', 'workmanager_one']);
      expect(runner.calls[2], <String>[
        '/Delete',
        '/TN',
        'workmanager_one',
        '/F',
      ]);
      expect(runner.calls[3], <String>['/End', '/TN', 'workmanager_two']);
      expect(runner.calls[4], <String>[
        '/Delete',
        '/TN',
        'workmanager_two',
        '/F',
      ]);
      expect(await store.read('one'), isNull);
      expect(await store.read('two'), isNull);
    });
  });

  group('queries', () {
    test('isScheduledByUniqueName is true when the task exists', () async {
      expect(await windows.isScheduledByUniqueName('demo'), isTrue);
      expect(runner.calls.single, <String>[
        '/Query',
        '/TN',
        'workmanager_demo',
      ]);
    });

    test('isScheduledByUniqueName is false when the task is missing', () async {
      runner.exitCode = 1;
      expect(await windows.isScheduledByUniqueName('demo'), isFalse);
    });

    test(
      'printScheduledTasks returns only tasks owned by the plugin',
      () async {
        runner.stdout = '"workmanager_demo","8/3/2026 11:15:00 AM","Ready"\n'
            '"workmanager_sync","8/4/2026 9:00:00 AM","Running"\n'
            '"SomeOtherTask","N/A","Disabled"';
        final json = await windows.printScheduledTasks();
        final decoded = jsonDecode(json) as List<dynamic>;
        expect(decoded, hasLength(2));
        expect(decoded[0], <String, String>{
          'TaskName': 'workmanager_demo',
          'NextRunTime': '8/3/2026 11:15:00 AM',
          'Status': 'Ready',
        });
        expect(decoded[1], <String, String>{
          'TaskName': 'workmanager_sync',
          'NextRunTime': '8/4/2026 9:00:00 AM',
          'Status': 'Running',
        });
      },
    );
  });

  group('dispatcher wiring', () {
    test('initialize stores the callback dispatcher in the registry', () async {
      void dispatcher() {}
      await windows.initialize(dispatcher);
      expect(WorkmanagerExecution.instance.callbackDispatcher, dispatcher);
    });

    test('executeTask registers the handler in the registry', () async {
      Future<bool> handler(
        String taskName,
        Map<String, dynamic>? inputData,
      ) async =>
          true;
      windows.executeTask(handler);
      expect(WorkmanagerExecution.instance.taskHandler, handler);
    });
  });

  group('unsupported surface', () {
    test('registerProcessingTask throws UnsupportedError', () {
      expect(
        () => windows.registerProcessingTask('p', 'p'),
        throwsUnsupportedError,
      );
    });

    test('registerHealthResearchTask throws UnsupportedError', () {
      expect(
        () => windows.registerHealthResearchTask('h', 'h'),
        throwsUnsupportedError,
      );
    });

    test('registerContinuedProcessingTask throws UnsupportedError', () {
      expect(
        () => windows.registerContinuedProcessingTask('c', 'c'),
        throwsUnsupportedError,
      );
    });

    test('cancelByTag throws UnsupportedError', () {
      expect(() => windows.cancelByTag('tag'), throwsUnsupportedError);
    });
  });

  group('task naming', () {
    test('taskIdFor prefixes unique names', () {
      expect(windows.taskIdFor('demo'), 'workmanager_demo');
    });
  });
}
