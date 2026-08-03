// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';
import 'package:workmanager_web/workmanager_web.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkmanagerWeb', () {
    test('registerWith installs the platform implementation', () {
      WorkmanagerWeb.registerWith(null);
      expect(WorkmanagerPlatform.instance, isA<WorkmanagerWeb>());
    });

    test('initialize is unsupported on non-web platforms', () {
      expectLater(
        WorkmanagerWeb().initialize((_) {}),
        throwsUnsupportedError,
      );
    });

    test('task registration requires initialize first', () {
      expectLater(
        WorkmanagerWeb().registerOneOffTask('unique', 'task'),
        throwsStateError,
      );
      expectLater(
        WorkmanagerWeb().registerPeriodicTask('unique', 'task'),
        throwsStateError,
      );
      expectLater(
        WorkmanagerWeb().cancelAll(),
        throwsStateError,
      );
    });

    test('platform-only task types throw UnsupportedError', () {
      expectLater(
        WorkmanagerWeb().registerProcessingTask('u', 't'),
        throwsUnsupportedError,
      );
      expectLater(
        WorkmanagerWeb().registerHealthResearchTask('u', 't'),
        throwsUnsupportedError,
      );
      expectLater(
        WorkmanagerWeb().registerContinuedProcessingTask('u', 't'),
        throwsUnsupportedError,
      );
    });

    test('work chaining throws UnsupportedError (Android-only)', () {
      expectLater(
        WorkmanagerWeb().beginUniqueWork(
          'chain',
          tasks: [WorkChainTask(taskName: 'step1')],
        ),
        throwsUnsupportedError,
      );
    });

    test('WorkmanagerWebEvent JSON round-trips', () {
      final event = WorkmanagerWebEvent(
        timestamp: DateTime.fromMillisecondsSinceEpoch(123456),
        state: 'executed',
        source: 'periodicsync',
        uniqueName: 'unique',
        taskName: 'task',
        result: true,
        message: 'done',
      );
      final restored = WorkmanagerWebEvent.fromJson(
        event.toJson().cast<Object?, Object?>(),
      );
      expect(restored.timestamp, event.timestamp);
      expect(restored.state, 'executed');
      expect(restored.source, 'periodicsync');
      expect(restored.uniqueName, 'unique');
      expect(restored.taskName, 'task');
      expect(restored.result, isTrue);
      expect(restored.message, 'done');
    });
  });
}
