// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'systemd.dart';

/// Persists task `inputData` to disk (Android-style on-disk payload) so the
/// headless `--background-task` process can load it back later.
///
/// Each payload is a JSON file named after the deterministic hash of the
/// task's [uniqueName], so re-registering a task overwrites its payload and
/// cancelling a task can remove it without scanning systemd state.
class PayloadStore {
  /// Creates a store rooted at [directory].
  PayloadStore(this.directory);

  /// Directory the payload JSON files live in.
  final Directory directory;

  /// Returns the payload file path for [uniqueName].
  String payloadPath(String uniqueName) {
    return '${directory.path}/workmanager-${SystemdNames.hash(uniqueName)}.json';
  }

  /// Writes [inputData] for [uniqueName] and returns the file path, or `null`
  /// when [inputData] is `null` (nothing to persist; the headless process
  /// then receives `null` input data).
  Future<String?> write(
    String uniqueName,
    Map<String, dynamic>? inputData,
  ) async {
    if (inputData == null) {
      return null;
    }
    final file = File(payloadPath(uniqueName));
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(inputData));
    return file.path;
  }

  /// Loads and decodes the payload at [path].
  ///
  /// Returns `null` when the file is missing or not valid JSON (the caller
  /// treats that as "no input data" and keeps running).
  Future<Map<String, dynamic>?> load(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return null;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
      return null;
    } on Object {
      return null;
    }
  }

  /// Deletes the payload for [uniqueName], if present.
  Future<void> delete(String uniqueName) async {
    final file = File(payloadPath(uniqueName));
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Deletes every payload file in the store.
  Future<void> clear() async {
    if (!await directory.exists()) {
      return;
    }
    await for (final entity in directory.list()) {
      if (entity is File) {
        await entity.delete();
      }
    }
  }
}
