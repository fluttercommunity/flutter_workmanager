// Copyright 2026 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// Builds `schtasks` command lines for the Task Scheduler operations used by
/// `workmanager_windows`.
///
/// v1 deliberately uses the `schtasks` command line only — no COM, no C++ and
/// no `win32` dependency — so every operation is a plain [ProcessRunner]
/// invocation and the package stays pure Dart and fully unit-testable off
/// Windows.
library;

/// Maximum repetition interval accepted by `schtasks /RI` (416 days).
const int maxRepetitionMinutes = 599940;

/// Builds `schtasks` command lines.
class Schtasks {
  Schtasks._();

  /// The `schtasks` executable name (resolved from `PATH` on Windows).
  static const String executable = 'schtasks';

  /// Builds `schtasks /Create` arguments for a one-off task that runs once at
  /// [startTime].
  static List<String> createOneOff({
    required String taskId,
    required String action,
    required DateTime startTime,
    bool overwrite = true,
  }) =>
      <String>[
        '/Create',
        '/TN',
        taskId,
        '/TR',
        action,
        '/SC',
        'ONCE',
        '/SD',
        formatDate(startTime),
        '/ST',
        formatTime(startTime),
        if (overwrite) '/F',
      ];

  /// Builds `schtasks /Create` arguments for a periodic task that repeats
  /// every [repeatMinutes] minutes (clamped to 1..[maxRepetitionMinutes]),
  /// anchored at [startTime].
  static List<String> createPeriodic({
    required String taskId,
    required String action,
    required DateTime startTime,
    required int repeatMinutes,
    bool overwrite = true,
  }) =>
      <String>[
        '/Create',
        '/TN',
        taskId,
        '/TR',
        action,
        '/SC',
        'DAILY',
        '/SD',
        formatDate(startTime),
        '/ST',
        formatTime(startTime),
        '/RI',
        '${repeatMinutes.clamp(1, maxRepetitionMinutes)}',
        if (overwrite) '/F',
      ];

  /// Builds the `/TR` action that launches the app headless:
  /// `<app.exe> --background-task <taskName> [--payload-file <path>]`.
  ///
  /// Paths and values are wrapped in inner quotes so paths containing spaces
  /// (e.g. `C:\Program Files\...`) survive Task Scheduler's command line
  /// parsing.
  static String buildAction({
    required String executablePath,
    required String taskName,
    String? payloadFilePath,
  }) {
    final buffer = StringBuffer('"$executablePath"');
    buffer.write(' --background-task "$taskName"');
    if (payloadFilePath != null) {
      buffer.write(' --payload-file "$payloadFilePath"');
    }
    return buffer.toString();
  }

  /// Builds `schtasks /End` arguments, stopping a running task instance.
  static List<String> end(String taskId) => <String>['/End', '/TN', taskId];

  /// Builds `schtasks /Delete` arguments, removing the task (including a
  /// running instance).
  static List<String> delete(String taskId) => <String>[
        '/Delete',
        '/TN',
        taskId,
        '/F',
      ];

  /// Builds `schtasks /Query` arguments for a single task.
  ///
  /// Exit code `0` means the task exists.
  static List<String> query(String taskId) => <String>['/Query', '/TN', taskId];

  /// Builds `schtasks /Query` arguments listing every task as CSV without a
  /// header row.
  static List<String> queryAllCsv() => <String>['/Query', '/FO', 'CSV', '/NH'];

  /// Maps a [frequency] to the `schtasks /RI` repetition interval in minutes:
  /// sub-minute frequencies are clamped to 1 minute, frequencies above
  /// [maxRepetitionMinutes] (416 days) are clamped to it.
  static int repeatMinutesFor(Duration frequency) => frequency.inMinutes.clamp(1, maxRepetitionMinutes);

  /// Formats [time] as `MM/DD/YYYY`.
  ///
  /// `schtasks` parses dates using the system's regional format; the
  /// MM/DD/YYYY form requires an English (en-US) style regional setting on
  /// the target machine.
  static String formatDate(DateTime time) =>
      '${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')}/${time.year}';

  /// Formats [time] as `HH:mm` (24-hour clock, zero-padded).
  static String formatTime(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  /// Rounds [time] to minute granularity, guaranteeing the result is strictly
  /// in the future relative to [now].
  ///
  /// Task Scheduler never runs a task whose scheduled start has already
  /// passed (a one-off task with a past start time silently never fires), so
  /// a zero `initialDelay` is rounded up to the next minute.
  static DateTime ensureFutureMinute(DateTime time, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final truncated = DateTime(
      time.year,
      time.month,
      time.day,
      time.hour,
      time.minute,
    );
    if (!truncated.isAfter(reference)) {
      return truncated.add(const Duration(minutes: 1));
    }
    return truncated;
  }

  /// Parses `schtasks /Query /FO CSV` output (with or without header row)
  /// into rows keyed by `TaskName`, `NextRunTime` and `Status`.
  ///
  /// Rows that do not have at least three columns are skipped. The parser is
  /// deliberately lenient: quoted fields are unquoted by stripping the outer
  /// quotes and splitting on `","` boundaries.
  static List<Map<String, String>> parseQueryCsv(String output) {
    final rows = <Map<String, String>>[];
    for (final line in output.trim().split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final parts = _splitCsvLine(trimmed);
      if (parts.length >= 3) {
        rows.add(<String, String>{
          'TaskName': parts[0],
          'NextRunTime': parts[1],
          'Status': parts[2],
        });
      }
    }
    return rows;
  }

  static List<String> _splitCsvLine(String line) {
    if (line.startsWith('"') && line.endsWith('"')) {
      return line.substring(1, line.length - 1).split('","');
    }
    return line.split(',');
  }
}
