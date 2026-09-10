// Copyright 2026 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';
import 'package:workmanager_windows/src/payload_store.dart';

void main() {
  late Directory tempDir;
  late PayloadStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wm_windows_payload_');
    store = PayloadStore(
      Directory('${tempDir.path}${Platform.pathSeparator}payloads'),
    );
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('PayloadStore.write/read', () {
    test('round-trips nested inputData through JSON', () async {
      final file = await store.write('demo', <String, dynamic>{
        'string': 'value',
        'int': 42,
        'double': 3.14,
        'bool': true,
        'null': null,
        'list': <dynamic>[1, 'two', false],
        'nested': <String, dynamic>{
          'deep': <String, dynamic>{'key': 1},
        },
      });
      expect(file, isNotNull);
      expect(await store.read('demo'), <String, dynamic>{
        'string': 'value',
        'int': 42,
        'double': 3.14,
        'bool': true,
        'null': null,
        'list': <dynamic>[1, 'two', false],
        'nested': <String, dynamic>{
          'deep': <String, dynamic>{'key': 1},
        },
      });
    });

    test(
      'write with null inputData creates no file and returns null',
      () async {
        final file = await store.write('demo', null);
        expect(file, isNull);
        expect(await store.read('demo'), isNull);
        expect(store.fileFor('demo').existsSync(), isFalse);
      },
    );

    test('read returns null for an unknown uniqueName', () async {
      expect(await store.read('missing'), isNull);
    });

    test('rejects non-JSON-encodable inputData', () async {
      expect(
        () => store.write('demo', <String, dynamic>{'obj': Object()}),
        throwsArgumentError,
      );
    });
  });

  group('PayloadStore.fileFor sanitization', () {
    test('replaces path separators and unsafe characters', () {
      final file = store.fileFor('../evil/name');
      expect(file.path, contains('__evil_name.json'));
      expect(file.path, isNot(contains('..')));
      expect(file.path, startsWith(store.directory.path));
    });

    test('keeps safe names intact', () {
      final file = store.fileFor('my_task-42');
      expect(file.path, endsWith('my_task-42.json'));
    });
  });

  group('PayloadStore.delete', () {
    test('deletes a single payload', () async {
      await store.write('demo', <String, dynamic>{'key': 'value'});
      await store.write('other', <String, dynamic>{'key': 'value'});
      await store.delete('demo');
      expect(await store.read('demo'), isNull);
      expect(await store.read('other'), isNotNull);
    });

    test('delete is a no-op for unknown names', () async {
      await store.delete('missing');
    });

    test('deleteAll clears every payload file', () async {
      await store.write('one', <String, dynamic>{'a': 1});
      await store.write('two', <String, dynamic>{'b': 2});
      await store.deleteAll();
      expect(await store.read('one'), isNull);
      expect(await store.read('two'), isNull);
    });
  });
}
