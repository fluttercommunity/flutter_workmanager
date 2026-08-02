// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager_web/src/worker_protocol.dart';

void main() {
  group('WorkerProtocol', () {
    test('executeTask encodes and decodes round-trip', () {
      final encoded = WorkerProtocol.encodeExecuteTask(
        requestId: 42,
        taskName: 'periodicTask',
        inputData: <String, Object?>{
          'count': 3,
          'flag': true,
        },
      );
      expect(encoded['type'], WorkerProtocol.typeExecuteTask);

      final decoded = WorkerProtocol.decodeExecuteTask(
        encoded.cast<Object?, Object?>(),
      );
      expect(decoded, isNotNull);
      expect(decoded!.requestId, 42);
      expect(decoded.taskName, 'periodicTask');
      expect(decoded.inputData, <String, Object?>{'count': 3, 'flag': true});
    });

    test('decodeExecuteTask rejects malformed messages', () {
      expect(
        WorkerProtocol.decodeExecuteTask(<Object?, Object?>{
          'type': WorkerProtocol.typeExecuteTask,
          'requestId': 'not-an-int',
          'taskName': 'x',
        }),
        isNull,
      );
      expect(
        WorkerProtocol.decodeExecuteTask(<Object?, Object?>{
          'type': WorkerProtocol.typeResult,
        }),
        isNull,
      );
    });

    test('result encodes and decodes round-trip', () {
      final encoded = WorkerProtocol.encodeResult(
        requestId: 7,
        result: true,
      );
      final decoded = WorkerProtocol.decodeResult(
        encoded.cast<Object?, Object?>(),
      );
      expect(decoded, isNotNull);
      expect(decoded!.requestId, 7);
      expect(decoded.result, isTrue);
      expect(decoded.error, isNull);
    });

    test('result carries error strings', () {
      final encoded = WorkerProtocol.encodeResult(
        requestId: 9,
        error: 'boom',
      );
      final decoded = WorkerProtocol.decodeResult(
        encoded.cast<Object?, Object?>(),
      );
      expect(decoded!.error, 'boom');
    });
  });
}
