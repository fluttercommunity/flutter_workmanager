// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';
import 'package:workmanager_linux/src/payload_store.dart';

void main() {
  late Directory tempDir;
  late PayloadStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('wm-payload-test-');
    store = PayloadStore(tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('payload path is deterministic per unique name', () {
    expect(store.payloadPath('task-a'), store.payloadPath('task-a'));
    expect(store.payloadPath('task-a'), isNot(store.payloadPath('task-b')));
  });

  test('write/load round-trips nested input data', () async {
    final path = await store.write('task-a', <String, dynamic>{
      'count': 3,
      'ratio': 0.5,
      'flag': true,
      'label': 'sync',
      'nested': <String, dynamic>{
        'list': <Object?>[1, 'two', false],
      },
    });
    expect(path, store.payloadPath('task-a'));
    expect(File(path!).existsSync(), isTrue);

    final loaded = await store.load(path);
    expect(loaded, <String, dynamic>{
      'count': 3,
      'ratio': 0.5,
      'flag': true,
      'label': 'sync',
      'nested': <String, dynamic>{
        'list': <Object?>[1, 'two', false],
      },
    });
  });

  test('write returns null for null input data and writes no file', () async {
    final path = await store.write('task-a', null);
    expect(path, isNull);
    expect(File(store.payloadPath('task-a')).existsSync(), isFalse);
  });

  test('load returns null for missing or invalid payloads', () async {
    expect(await store.load('${tempDir.path}/nope.json'), isNull);

    final bad = File('${tempDir.path}/bad.json');
    await bad.writeAsString('not json {');
    expect(await store.load(bad.path), isNull);
  });

  test('overwriting a payload replaces its content', () async {
    await store.write('task-a', <String, dynamic>{'run': 1});
    final path = await store.write('task-a', <String, dynamic>{'run': 2});
    expect(await store.load(path!), <String, dynamic>{'run': 2});
  });

  test('delete removes the payload file', () async {
    await store.write('task-a', <String, dynamic>{'run': 1});
    await store.delete('task-a');
    expect(File(store.payloadPath('task-a')).existsSync(), isFalse);
  });

  test('clear removes every payload', () async {
    await store.write('task-a', <String, dynamic>{'run': 1});
    await store.write('task-b', <String, dynamic>{'run': 2});
    await store.clear();
    expect(File(store.payloadPath('task-a')).existsSync(), isFalse);
    expect(File(store.payloadPath('task-b')).existsSync(), isFalse);
  });
}
