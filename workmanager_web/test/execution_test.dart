// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager_web/workmanager_web.dart';

void main() {
  group('WorkmanagerExecution', () {
    test('executeTask registers the handler and runTask invokes it', () async {
      final execution = WorkmanagerExecution.instance;
      execution.executeTask((taskName, inputData) async {
        expect(taskName, 'demo');
        expect(inputData, <String, dynamic>{'key': 'value'});
        return true;
      });
      final result = await execution.runTask(
        'demo',
        <String, Object?>{'key': 'value'},
      );
      expect(result, isTrue);
    });

    test('runTask returns false when no handler is registered', () async {
      final execution = WorkmanagerExecution.instance;
      execution.taskHandler = null;
      final result = await execution.runTask('unregistered', null);
      expect(result, isFalse);
    });

    test('normalizeInputData deep-normalizes maps and lists', () {
      final execution = WorkmanagerExecution.instance;
      final normalized = execution.normalizeInputData(<Object?, Object?>{
        'nested': <Object?, Object?>{
          'list': <Object?>[1, 2, 3],
        },
        42: 'ignored-non-string-key',
      });
      expect(
        normalized,
        <String, dynamic>{
          'nested': <String, dynamic>{
            'list': <Object?>[1, 2, 3],
          },
        },
      );
    });

    test('normalizeInputData wraps non-map values', () {
      final execution = WorkmanagerExecution.instance;
      expect(
        execution.normalizeInputData('just a string'),
        <String, dynamic>{'value': 'just a string'},
      );
      expect(execution.normalizeInputData(null), isNull);
    });

    test('messageHandler receives messages sent to the worker', () {
      final execution = WorkmanagerExecution.instance;
      Object? received;
      execution.messageHandler = (Object? payload) {
        received = payload;
      };
      execution.messageHandler?.call(<String, Object?>{'op': 'watch'});
      expect(received, <String, Object?>{'op': 'watch'});
    });

    test('sendToPage delivers messages back to the page', () {
      final execution = WorkmanagerExecution.instance;
      Object? delivered;
      execution.sendToPage = (Object? payload) {
        delivered = payload;
      };
      execution.sendToPage?.call(<String, Object?>{'kind': 'tick'});
      expect(delivered, <String, Object?>{'kind': 'tick'});
    });
  });
}
