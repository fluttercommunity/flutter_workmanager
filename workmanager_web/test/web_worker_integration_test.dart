// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager_web/src/worker_protocol.dart';

void main() {
  test('worker message contract round-trips in a real Web Worker', () async {
    final workerUrl = _createBlobWorkerUrl('''
self.onmessage = (event) => {
  const data = event.data || {};
  if (data.type === 'executeTask') {
    self.postMessage({
      type: 'result',
      requestId: data.requestId,
      result: 'ok:' + data.taskName + ':' + JSON.stringify(data.inputData),
      error: null,
    });
  }
};
''');
    final worker = _createWorker(workerUrl);
    addTearDown(() => worker.callMethod('terminate'.toJS));

    final reply = await _postAndAwait(
      worker,
      WorkerProtocol.encodeExecuteTask(
        requestId: 7,
        taskName: 'demoTask',
        inputData: <String, Object?>{'a': 1, 'b': 'two'},
      ),
    );

    expect(reply, isA<Map>());
    final decoded = WorkerProtocol.decodeResult(
      (reply! as Map).cast<Object?, Object?>(),
    );
    expect(decoded, isNotNull);
    expect(decoded!.requestId, 7);
    expect(decoded.error, isNull);
    expect(decoded.result, 'ok:demoTask:{"a":1,"b":"two"}');
  });
}

String _createBlobWorkerUrl(String code) {
  final urlConstructor = globalContext['URL'] as JSObject;
  final blobConstructor = globalContext['Blob'] as JSFunction;
  final blob = blobConstructor.callAsConstructor(
    <Object?>[code].jsify(),
    <String, Object?>{'type': 'application/javascript'}.jsify(),
  );
  final url =
      urlConstructor.callMethod('createObjectURL'.toJS, blob) as JSString;
  return url.toDart;
}

JSObject _createWorker(String scriptUrl) {
  final workerConstructor = globalContext['Worker'] as JSFunction;
  return workerConstructor.callAsConstructor(scriptUrl.toJS) as JSObject;
}

Future<Object?> _postAndAwait(
  JSObject worker,
  Map<String, Object?> message,
) {
  final completer = Completer<Object?>();
  worker.callMethod(
    'addEventListener'.toJS,
    'message'.toJS,
    ((JSObject event) {
      final data = event['data']?.dartify();
      if (!completer.isCompleted) {
        completer.complete(data);
      }
    }).toJS,
  );
  worker.callMethod('postMessage'.toJS, message.jsify());
  return completer.future.timeout(const Duration(seconds: 10));
}
