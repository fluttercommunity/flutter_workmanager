// Copyright 2026 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:workmanager_windows/execution.dart';

void main() {
  group('WorkmanagerExecution', () {
    test('executeTask registers the handler and runTask invokes it', () async {
      final execution = WorkmanagerExecution.instance;
      execution.executeTask((taskName, inputData) async {
        expect(taskName, 'demo');
        expect(inputData, <String, dynamic>{'key': 'value'});
        return true;
      });
      final result = await execution.runTask('demo', <String, dynamic>{
        'key': 'value',
      });
      expect(result, isTrue);
    });

    test('runTask returns false when no handler is registered', () async {
      final execution = WorkmanagerExecution.instance;
      execution.taskHandler = null;
      final result = await execution.runTask('unregistered', null);
      expect(result, isFalse);
    });
  });

  group('argument parsing', () {
    test('backgroundTaskNameFromArgs returns the task name', () {
      expect(
        backgroundTaskNameFromArgs(<String>[
          '--background-task',
          'demo',
          '--payload-file',
          'C:\\p.json',
        ]),
        'demo',
      );
    });

    test('backgroundTaskNameFromArgs returns null without the flag', () {
      expect(backgroundTaskNameFromArgs(<String>['--foo', 'bar']), isNull);
    });

    test('backgroundTaskNameFromArgs returns null when the flag is last', () {
      expect(backgroundTaskNameFromArgs(<String>['--background-task']), isNull);
    });

    test('payloadFilePathFromArgs returns the path', () {
      expect(
        payloadFilePathFromArgs(<String>[
          '--background-task',
          'demo',
          '--payload-file',
          'C:\\AppData\\payload.json',
        ]),
        'C:\\AppData\\payload.json',
      );
    });

    test('payloadFilePathFromArgs returns null when absent', () {
      expect(
        payloadFilePathFromArgs(<String>['--background-task', 'demo']),
        isNull,
      );
    });
  });

  group('runBackgroundTask', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('wm_windows_exec_');
      WorkmanagerExecution.instance.taskHandler = null;
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    Future<String> writePayload(Map<String, dynamic> payload) async {
      final file = File('${tempDir.path}${Platform.pathSeparator}payload.json');
      await file.writeAsString(jsonEncode(payload));
      return file.path;
    }

    test('runs the registered handler with the persisted payload', () async {
      final payloadPath = await writePayload(<String, dynamic>{'n': 1});
      var ran = false;
      final exitCode = await runBackgroundTask(
        'demo',
        payloadFilePath: payloadPath,
        callbackDispatcher: () {
          WorkmanagerExecution.instance.executeTask((
            taskName,
            inputData,
          ) async {
            ran = true;
            expect(taskName, 'demo');
            expect(inputData, <String, dynamic>{'n': 1});
            return true;
          });
        },
      );
      expect(ran, isTrue);
      expect(exitCode, 0);
    });

    test('passes null inputData when no payload file was given', () async {
      final exitCode = await runBackgroundTask(
        'demo',
        payloadFilePath: null,
        callbackDispatcher: () {
          WorkmanagerExecution.instance.executeTask((
            taskName,
            inputData,
          ) async {
            expect(inputData, isNull);
            return true;
          });
        },
      );
      expect(exitCode, 0);
    });

    test('passes null inputData when the payload file is missing', () async {
      final exitCode = await runBackgroundTask(
        'demo',
        payloadFilePath: '${tempDir.path}${Platform.pathSeparator}nope.json',
        callbackDispatcher: () {
          WorkmanagerExecution.instance.executeTask((
            taskName,
            inputData,
          ) async {
            expect(inputData, isNull);
            return true;
          });
        },
      );
      expect(exitCode, 0);
    });

    test('returns 1 when the handler returns false', () async {
      final exitCode = await runBackgroundTask(
        'demo',
        payloadFilePath: null,
        callbackDispatcher: () {
          WorkmanagerExecution.instance.executeTask((
            taskName,
            inputData,
          ) async {
            return false;
          });
        },
      );
      expect(exitCode, 1);
    });

    test('returns 1 when the handler throws', () async {
      final exitCode = await runBackgroundTask(
        'demo',
        payloadFilePath: null,
        callbackDispatcher: () {
          WorkmanagerExecution.instance.executeTask((
            taskName,
            inputData,
          ) async {
            throw StateError('boom');
          });
        },
      );
      expect(exitCode, 1);
    });

    test('returns 1 when no handler was registered', () async {
      final exitCode = await runBackgroundTask(
        'demo',
        payloadFilePath: null,
        callbackDispatcher: () {},
      );
      expect(exitCode, 1);
    });
  });
}
