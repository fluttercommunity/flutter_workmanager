// Copyright 2026 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

/// Persists task `inputData` as JSON files on disk (an Android-style on-disk
/// payload), one file per `uniqueName`.
///
/// The file path is embedded in the registered Task Scheduler action and
/// passed to the headless process via `--payload-file <path>`, mirroring how
/// `workmanager_android` keeps task payloads out of the scheduling layer.
class PayloadStore {
  /// Creates a store rooted at [directory].
  PayloadStore(this.directory);

  /// Directory holding one `<uniqueName>.json` file per registered task.
  final Directory directory;

  /// Returns the payload file for [uniqueName].
  ///
  /// The name is sanitized (characters outside `[A-Za-z0-9_-]` are replaced
  /// with `_`) so a `uniqueName` can never escape [directory].
  File fileFor(String uniqueName) {
    final sanitized = uniqueName.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    return File('${directory.path}${Platform.pathSeparator}$sanitized.json');
  }

  /// Writes [inputData] for [uniqueName].
  ///
  /// Returns the written file, or `null` when [inputData] is `null` (no
  /// payload file is created). Throws [ArgumentError] when [inputData] is not
  /// JSON-encodable.
  Future<File?> write(
    String uniqueName,
    Map<String, dynamic>? inputData,
  ) async {
    if (inputData == null) {
      return null;
    }
    final file = fileFor(uniqueName);
    try {
      await directory.create(recursive: true);
      await file.writeAsString(jsonEncode(inputData));
    } on JsonUnsupportedObjectError catch (error) {
      throw ArgumentError(
        'inputData for "$uniqueName" is not JSON-encodable: $error',
      );
    }
    return file;
  }

  /// Reads back the payload for [uniqueName], or `null` when absent or not a
  /// JSON object.
  Future<Map<String, dynamic>?> read(String uniqueName) async {
    final file = fileFor(uniqueName);
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  /// Deletes the payload file for [uniqueName], if any.
  Future<void> delete(String uniqueName) async {
    final file = fileFor(uniqueName);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Deletes every payload file in [directory].
  Future<void> deleteAll() async {
    if (!await directory.exists()) {
      return;
    }
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        await entity.delete();
      }
    }
  }
}
