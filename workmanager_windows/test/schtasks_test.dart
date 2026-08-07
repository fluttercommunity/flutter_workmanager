// Copyright 2026 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:workmanager_windows/src/schtasks.dart';

void main() {
  group('Schtasks.createOneOff', () {
    final startTime = DateTime(2026, 8, 3, 11, 15);

    test('builds a /SC ONCE task with /SD, /ST and /F', () {
      expect(
        Schtasks.createOneOff(
          taskId: 'workmanager_demo',
          action: '"C:\\App.exe" --background-task "demo"',
          startTime: startTime,
        ),
        <String>[
          '/Create',
          '/TN',
          'workmanager_demo',
          '/TR',
          '"C:\\App.exe" --background-task "demo"',
          '/SC',
          'ONCE',
          '/SD',
          '08/03/2026',
          '/ST',
          '11:15',
          '/F',
        ],
      );
    });

    test('omits /F when overwrite is false', () {
      final args = Schtasks.createOneOff(
        taskId: 'workmanager_demo',
        action: 'app.exe',
        startTime: startTime,
        overwrite: false,
      );
      expect(args, isNot(contains('/F')));
    });
  });

  group('Schtasks.createPeriodic', () {
    final startTime = DateTime(2026, 8, 3, 9, 0);

    test('builds a /SC DAILY task with /RI repetition', () {
      expect(
        Schtasks.createPeriodic(
          taskId: 'workmanager_sync',
          action: '"C:\\App.exe" --background-task "sync"',
          startTime: startTime,
          repeatMinutes: 30,
        ),
        <String>[
          '/Create',
          '/TN',
          'workmanager_sync',
          '/TR',
          '"C:\\App.exe" --background-task "sync"',
          '/SC',
          'DAILY',
          '/SD',
          '08/03/2026',
          '/ST',
          '09:00',
          '/RI',
          '30',
          '/F',
        ],
      );
    });

    test('clamps the repetition interval to the schtasks range', () {
      final args = Schtasks.createPeriodic(
        taskId: 'workmanager_sync',
        action: 'app.exe',
        startTime: startTime,
        repeatMinutes: 1000000,
      );
      expect(args[args.indexOf('/RI') + 1], '$maxRepetitionMinutes');
    });
  });

  group('Schtasks.buildAction', () {
    test('wraps paths with spaces in inner quotes', () {
      expect(
        Schtasks.buildAction(
          executablePath: 'C:\\Program Files\\My App\\my_app.exe',
          taskName: 'demo',
        ),
        '"C:\\Program Files\\My App\\my_app.exe" --background-task "demo"',
      );
    });

    test('appends --payload-file only when a path is given', () {
      final action = Schtasks.buildAction(
        executablePath: 'C:\\App.exe',
        taskName: 'demo',
        payloadFilePath: 'C:\\Users\\me\\payload.json',
      );
      expect(
        action,
        '"C:\\App.exe" --background-task "demo" '
        '--payload-file "C:\\Users\\me\\payload.json"',
      );
    });
  });

  group('Schtasks end/delete/query', () {
    test('end stops a running task', () {
      expect(
        Schtasks.end('workmanager_demo'),
        <String>['/End', '/TN', 'workmanager_demo'],
      );
    });

    test('delete removes a task including a running instance', () {
      expect(
        Schtasks.delete('workmanager_demo'),
        <String>['/Delete', '/TN', 'workmanager_demo', '/F'],
      );
    });

    test('query targets a single task', () {
      expect(
        Schtasks.query('workmanager_demo'),
        <String>['/Query', '/TN', 'workmanager_demo'],
      );
    });

    test('queryAllCsv lists all tasks without a header', () {
      expect(
        Schtasks.queryAllCsv(),
        <String>['/Query', '/FO', 'CSV', '/NH'],
      );
    });
  });

  group('Schtasks formatting', () {
    test('formatDate zero-pads month and day as MM/DD/YYYY', () {
      expect(Schtasks.formatDate(DateTime(2026, 3, 8, 9, 0)), '03/08/2026');
      expect(Schtasks.formatDate(DateTime(2026, 12, 25, 9, 0)), '12/25/2026');
    });

    test('formatTime zero-pads as HH:mm on a 24-hour clock', () {
      expect(Schtasks.formatTime(DateTime(2026, 8, 3, 9, 5)), '09:05');
      expect(Schtasks.formatTime(DateTime(2026, 8, 3, 23, 59)), '23:59');
    });
  });

  group('Schtasks.repeatMinutesFor', () {
    test('clamps sub-minute frequencies to one minute', () {
      expect(Schtasks.repeatMinutesFor(const Duration(seconds: 30)), 1);
      expect(Schtasks.repeatMinutesFor(const Duration(seconds: 90)), 1);
    });

    test('maps multi-day frequencies to minutes', () {
      expect(Schtasks.repeatMinutesFor(const Duration(days: 2)), 2880);
    });

    test('caps frequencies above the schtasks maximum', () {
      expect(
        Schtasks.repeatMinutesFor(const Duration(days: 500)),
        maxRepetitionMinutes,
      );
    });
  });

  group('Schtasks.ensureFutureMinute', () {
    final now = DateTime(2026, 8, 3, 11, 15, 30);

    test('rounds a past or current-minute time up to the next minute', () {
      final rounded = Schtasks.ensureFutureMinute(
        DateTime(2026, 8, 3, 11, 15, 10),
        now: now,
      );
      expect(rounded, DateTime(2026, 8, 3, 11, 16));
    });

    test('keeps a future time truncated to minute granularity', () {
      final rounded = Schtasks.ensureFutureMinute(
        DateTime(2026, 8, 3, 11, 17, 45),
        now: now,
      );
      expect(rounded, DateTime(2026, 8, 3, 11, 17));
    });
  });

  group('Schtasks.parseQueryCsv', () {
    test('parses quoted CSV rows into TaskName/NextRunTime/Status', () {
      const output = '"workmanager_demo","8/3/2026 11:15:00 AM","Ready"\n'
          '"workmanager_sync","8/4/2026 9:00:00 AM","Running"\n'
          '"SomeOtherTask","N/A","Disabled"';
      final rows = Schtasks.parseQueryCsv(output);
      expect(rows, <Map<String, String>>[
        <String, String>{
          'TaskName': 'workmanager_demo',
          'NextRunTime': '8/3/2026 11:15:00 AM',
          'Status': 'Ready',
        },
        <String, String>{
          'TaskName': 'workmanager_sync',
          'NextRunTime': '8/4/2026 9:00:00 AM',
          'Status': 'Running',
        },
        <String, String>{
          'TaskName': 'SomeOtherTask',
          'NextRunTime': 'N/A',
          'Status': 'Disabled',
        },
      ]);
    });

    test('skips empty lines and malformed rows', () {
      const output = '\n"workmanager_demo","8/3/2026 11:15:00 AM","Ready"\n'
          '"too","few"\n';
      final rows = Schtasks.parseQueryCsv(output);
      expect(rows, hasLength(1));
      expect(rows.single['TaskName'], 'workmanager_demo');
    });
  });
}
