// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:workmanager_linux/src/process_runner.dart';
import 'package:workmanager_linux/src/systemd.dart';
import 'package:workmanager_linux/workmanager_linux.dart';

/// Records every invocation and returns scriptable results; never touches a
/// real systemd.
class FakeProcessRunner implements ProcessRunner {
  final List<List<String>> calls = <List<String>>[];
  int exitCode = 0;
  String stdout = '';
  bool throwOnRun = false;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    if (throwOnRun) {
      throw ProcessException(executable, arguments, 'no systemd here');
    }
    calls.add(<String>[executable, ...arguments]);
    return ProcessResult(0, exitCode, stdout, '');
  }
}

void main() {
  late Directory tempDir;
  late String unitsDir;
  late String payloadDir;
  late FakeProcessRunner runner;
  late WorkmanagerLinux linux;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('wm-linux-test-');
    unitsDir = '${tempDir.path}/units';
    payloadDir = '${tempDir.path}/payloads';
    runner = FakeProcessRunner();
    linux = WorkmanagerLinux(
      processRunner: runner,
      binaryPath: '/opt/app/example',
      unitsDirectory: unitsDir,
      payloadDirectory: payloadDir,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    WorkmanagerExecution.instance.taskHandler = null;
  });

  String payloadPathFor(String uniqueName) =>
      '$payloadDir/workmanager-${SystemdNames.hash(uniqueName)}.json';

  test('registerOneOffTask schedules a transient unit for an immediate run',
      () async {
    await linux.registerOneOffTask('task-a', 'sync',
        inputData: <String, dynamic>{'key': 'value'});

    expect(runner.calls, hasLength(1));
    expect(runner.calls.single, <String>[
      'systemd-run',
      '--user',
      '--collect',
      '--unit=workmanager-${SystemdNames.hash('task-a')}',
      '--no-block',
      '/opt/app/example',
      '--background-task',
      'sync',
      '--payload',
      payloadPathFor('task-a'),
    ]);
    final payload = File(payloadPathFor('task-a'));
    expect(payload.existsSync(), isTrue);
    expect(jsonDecode(payload.readAsStringSync()),
        <String, dynamic>{'key': 'value'});
  });

  test('registerOneOffTask honors the initial delay', () async {
    await linux.registerOneOffTask(
      'task-a',
      'sync',
      initialDelay: const Duration(minutes: 5),
    );

    expect(runner.calls.single, contains('--on-active=300'));
    expect(runner.calls.single, isNot(contains('--no-block')));
  });

  test('registerOneOffTask omits --payload when inputData is null', () async {
    await linux.registerOneOffTask('task-a', 'sync');
    expect(runner.calls.single, isNot(contains('--payload')));
    expect(File(payloadPathFor('task-a')).existsSync(), isFalse);
  });

  test('registerPeriodicTask writes unit files and enables the timer',
      () async {
    await linux.registerPeriodicTask(
      'task-p',
      'periodic',
      inputData: <String, dynamic>{'freq': 'hourly'},
      frequency: const Duration(hours: 1),
      initialDelay: const Duration(minutes: 2),
    );

    final serviceFile =
        File('$unitsDir/workmanager-${SystemdNames.hash('task-p')}.service');
    final timerFile =
        File('$unitsDir/workmanager-${SystemdNames.hash('task-p')}.timer');
    expect(serviceFile.existsSync(), isTrue);
    expect(timerFile.existsSync(), isTrue);

    final service = serviceFile.readAsStringSync();
    expect(service, contains('Type=oneshot'));
    expect(
        service,
        contains('ExecStart=/opt/app/example --background-task '
            'periodic --payload ${payloadPathFor('task-p')}'));

    final timer = timerFile.readAsStringSync();
    expect(timer, contains('OnUnitActiveSec=3600'));
    expect(timer, contains('OnStartupSec=120'));
    expect(timer, contains('Persistent=true'));
    expect(timer,
        contains('Unit=workmanager-${SystemdNames.hash('task-p')}.service'));

    expect(runner.calls, <List<String>>[
      <String>['systemctl', '--user', 'daemon-reload'],
      <String>[
        'systemctl',
        '--user',
        'enable',
        '--now',
        'workmanager-${SystemdNames.hash('task-p')}.timer',
      ],
    ]);
  });

  test('registerPeriodicTask defaults the frequency to 15 minutes', () async {
    await linux.registerPeriodicTask('task-p', 'periodic');
    final timerFile =
        File('$unitsDir/workmanager-${SystemdNames.hash('task-p')}.timer');
    expect(timerFile.readAsStringSync(), contains('OnUnitActiveSec=900'));
  });

  test('cancelByUniqueName stops, disables and removes the units', () async {
    await linux.registerPeriodicTask('task-p', 'periodic');
    runner.calls.clear();

    await linux.cancelByUniqueName('task-p');

    expect(runner.calls, <List<String>>[
      <String>[
        'systemctl',
        '--user',
        'stop',
        'workmanager-${SystemdNames.hash('task-p')}.timer',
        'workmanager-${SystemdNames.hash('task-p')}.service',
      ],
      <String>[
        'systemctl',
        '--user',
        'disable',
        'workmanager-${SystemdNames.hash('task-p')}.timer',
      ],
      <String>[
        'systemctl',
        '--user',
        'reset-failed',
        'workmanager-${SystemdNames.hash('task-p')}.timer',
        'workmanager-${SystemdNames.hash('task-p')}.service',
      ],
      <String>['systemctl', '--user', 'daemon-reload'],
    ]);
    expect(
        File('$unitsDir/workmanager-${SystemdNames.hash('task-p')}.timer')
            .existsSync(),
        isFalse);
    expect(
        File('$unitsDir/workmanager-${SystemdNames.hash('task-p')}.service')
            .existsSync(),
        isFalse);
  });

  test('cancelAll stops every workmanager unit and clears state', () async {
    await linux.registerPeriodicTask('task-p', 'periodic');
    await linux.registerOneOffTask('task-a', 'sync',
        inputData: <String, dynamic>{'k': 'v'});
    runner.calls.clear();

    await linux.cancelAll();

    expect(runner.calls, <List<String>>[
      <String>['systemctl', '--user', 'stop', 'workmanager-*.timer'],
      <String>['systemctl', '--user', 'stop', 'workmanager-*.service'],
      <String>['systemctl', '--user', 'disable', 'workmanager-*.timer'],
      <String>['systemctl', '--user', 'reset-failed', 'workmanager-*'],
      <String>['systemctl', '--user', 'daemon-reload'],
    ]);
    expect(Directory(unitsDir).listSync(), isEmpty);
    expect(Directory(payloadDir).listSync(), isEmpty);
  });

  test('isScheduledByUniqueName maps the is-active exit code', () async {
    runner.exitCode = 0;
    expect(await linux.isScheduledByUniqueName('task-a'), isTrue);
    expect(runner.calls.single, <String>[
      'systemctl',
      '--user',
      'is-active',
      'workmanager-${SystemdNames.hash('task-a')}.timer',
    ]);

    runner.calls.clear();
    runner.exitCode = 3;
    expect(await linux.isScheduledByUniqueName('task-a'), isFalse);
  });

  test('printScheduledTasks returns only workmanager timer lines', () async {
    runner.stdout = [
      'Mon 2026-08-03 12:00:00 BST 1h 0s left Sun 2026-08-02 12:00:00 BST 1 day ago workmanager-1234abcd.timer workmanager-1234abcd.service',
      'Mon 2026-08-03 13:00:00 BST 2h 0s left Mon 2026-08-02 13:00:00 BST 1 day ago user-backup.timer user-backup.service',
    ].join('\n');

    final result = await linux.printScheduledTasks();

    expect(result, contains('workmanager-1234abcd.timer'));
    expect(result, isNot(contains('user-backup.timer')));
    expect(runner.calls.single, <String>[
      'systemctl',
      '--user',
      'list-timers',
      '--all',
      '--no-legend',
      '--plain',
    ]);
  });

  test('missing systemctl surfaces a descriptive StateError', () async {
    runner.throwOnRun = true;
    await expectLater(
      linux.registerOneOffTask('task-a', 'sync'),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('systemd user session'),
      )),
    );
  });

  test('unsupported APIs throw UnsupportedError', () async {
    await expectLater(
        linux.registerProcessingTask('u', 't'), throwsUnsupportedError);
    await expectLater(
        linux.registerHealthResearchTask('u', 't'), throwsUnsupportedError);
    await expectLater(linux.registerContinuedProcessingTask('u', 't'),
        throwsUnsupportedError);
    await expectLater(linux.cancelByTag('tag'), throwsUnsupportedError);
  });

  test('executeTask registers the handler in the execution registry', () async {
    String? seenTask;
    WorkmanagerLinux.executeTask((taskName, inputData) async {
      seenTask = taskName;
      return true;
    });
    final result = await WorkmanagerExecution.instance.runTask('sync', null);
    expect(result, isTrue);
    expect(seenTask, 'sync');
  });

  test('initialize stores the dispatcher on Linux, rejects other hosts',
      () async {
    var ran = false;
    void dispatcher() {
      ran = true;
    }

    if (Platform.isLinux) {
      await linux.initialize(dispatcher);
      expect(
          WorkmanagerExecution.instance.callbackDispatcher, same(dispatcher));
      expect(ran, isFalse);
    } else {
      // The initialize() guard rejects non-Linux hosts with a clear error.
      await expectLater(linux.initialize(dispatcher), throwsUnsupportedError);
      expect(ran, isFalse);
    }
  });

  test('maybeRunBackgroundTask returns false for normal app arguments',
      () async {
    final result =
        await WorkmanagerLinux.maybeRunBackgroundTask(<String>[], () {});
    expect(result, isFalse);
    expect(runner.calls, isEmpty);
  });
}
