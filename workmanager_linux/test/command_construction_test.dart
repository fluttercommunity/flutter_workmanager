// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:workmanager_linux/src/systemd.dart';
import 'package:workmanager_linux/src/systemd_units.dart';

void main() {
  group('SystemdNames', () {
    test('unit names are deterministic and stable across calls', () {
      expect(SystemdNames.unit('my-task'), SystemdNames.unit('my-task'));
      expect(SystemdNames.hash('my-task'), SystemdNames.hash('my-task'));
    });

    test('different unique names produce different units', () {
      expect(SystemdNames.unit('task-a'), isNot(SystemdNames.unit('task-b')));
    });

    test('unit names only use safe systemd characters', () {
      for (final name in <String>[
        'simple',
        'with space',
        'with/slash',
        'with:colon',
        'uni🙂code',
        '',
      ]) {
        final unit = SystemdNames.unit(name);
        expect(
          unit,
          matches(RegExp(r'^workmanager-[0-9a-f]{8}$')),
          reason: 'unexpected unit name for "$name": $unit',
        );
      }
    });

    test('timer and service units derive from the base unit', () {
      final base = SystemdNames.unit('demo');
      expect(SystemdNames.timerUnit('demo'), '$base.timer');
      expect(SystemdNames.serviceUnit('demo'), '$base.service');
    });

    test('description strips control characters', () {
      expect(
        SystemdNames.description('line one\nline two\t\x00'),
        'line one line two  ',
      );
    });
  });

  group('SystemdUnitFiles.service', () {
    test('is a Type=oneshot unit running the app headless', () {
      final content = SystemdUnitFiles.service(
        description: 'Workmanager task "sync" (task-id)',
        execArgs: <String>[
          '/opt/app/bin/example',
          '--background-task',
          'sync',
          '--payload',
          '/home/u/.local/share/workmanager/payloads/workmanager-1234abcd.json',
        ],
      );
      expect(content, contains('[Unit]'));
      expect(
        content,
        contains('Description=Workmanager task "sync" (task-id)'),
      );
      expect(content, contains('[Service]'));
      expect(content, contains('Type=oneshot'));
      expect(
        content,
        contains(
          'ExecStart=/opt/app/bin/example --background-task sync '
          '--payload /home/u/.local/share/workmanager/payloads/'
          'workmanager-1234abcd.json',
        ),
      );
    });

    test('quotes arguments containing spaces', () {
      final content = SystemdUnitFiles.service(
        description: 'quoted',
        execArgs: <String>[
          '/opt/My App/example',
          '--background-task',
          'task with space',
        ],
      );
      expect(
        content,
        contains('ExecStart="/opt/My App/example" --background-task '
            '"task with space"'),
      );
    });
  });

  group('SystemdUnitFiles.timer', () {
    test('uses OnUnitActiveSec for the frequency and enables catch-up', () {
      final content = SystemdUnitFiles.timer(
        description: 'periodic',
        frequency: const Duration(minutes: 15),
        serviceUnit: 'workmanager-1234abcd.service',
      );
      expect(content, contains('[Timer]'));
      expect(content, contains('OnUnitActiveSec=900'));
      expect(content, contains('Persistent=true'));
      expect(
        content,
        contains('Unit=workmanager-1234abcd.service'),
      );
      expect(content, contains('[Install]'));
      expect(content, contains('WantedBy=timers.target'));
      expect(content, isNot(contains('OnStartupSec')));
    });

    test('adds OnStartupSec for the initial delay', () {
      final content = SystemdUnitFiles.timer(
        description: 'periodic',
        frequency: const Duration(hours: 1),
        initialDelay: const Duration(minutes: 5),
        serviceUnit: 'workmanager-1234abcd.service',
      );
      expect(content, contains('OnStartupSec=300'));
      expect(content, contains('OnUnitActiveSec=3600'));
    });

    test('omits OnStartupSec for zero or negative delays', () {
      for (final delay in <Duration?>[
        null,
        Duration.zero,
        const Duration(seconds: -5),
      ]) {
        final content = SystemdUnitFiles.timer(
          description: 'periodic',
          frequency: const Duration(minutes: 15),
          initialDelay: delay,
          serviceUnit: 'workmanager-1234abcd.service',
        );
        expect(content, isNot(contains('OnStartupSec')),
            reason: 'delay was $delay');
      }
    });
  });

  group('SystemdCommands', () {
    const commands =
        SystemdCommands(systemctl: 'systemctl', systemdRun: 'systemd-run');
    final appCommand = <String>[
      '/opt/app/example',
      '--background-task',
      'sync',
      '--payload',
      '/tmp/payload.json',
    ];

    test('one-off with delay uses a transient timer', () {
      final args = commands.runOneOff(
        unit: 'workmanager-1234abcd',
        delay: const Duration(minutes: 5),
        appCommand: appCommand,
      );
      expect(args, <String>[
        'systemd-run',
        '--user',
        '--collect',
        '--unit=workmanager-1234abcd',
        '--on-active=300',
        ...appCommand,
      ]);
    });

    test('one-off without delay runs immediately with --no-block', () {
      final args = commands.runOneOff(
        unit: 'workmanager-1234abcd',
        delay: Duration.zero,
        appCommand: appCommand,
      );
      expect(args, contains('--no-block'));
      expect(args, isNot(contains(startsWith('--on-active'))));
    });

    test('cancel, query and list commands', () {
      expect(commands.stop('workmanager-1234abcd'), <String>[
        'systemctl',
        '--user',
        'stop',
        'workmanager-1234abcd.timer',
        'workmanager-1234abcd.service',
      ]);
      expect(commands.disable('workmanager-1234abcd.timer'), <String>[
        'systemctl',
        '--user',
        'disable',
        'workmanager-1234abcd.timer',
      ]);
      expect(commands.resetFailed('workmanager-1234abcd'), <String>[
        'systemctl',
        '--user',
        'reset-failed',
        'workmanager-1234abcd.timer',
        'workmanager-1234abcd.service',
      ]);
      expect(commands.isActive('workmanager-1234abcd.timer'), <String>[
        'systemctl',
        '--user',
        'is-active',
        'workmanager-1234abcd.timer',
      ]);
      expect(commands.daemonReload(), <String>[
        'systemctl',
        '--user',
        'daemon-reload',
      ]);
      expect(commands.enableNow('workmanager-1234abcd.timer'), <String>[
        'systemctl',
        '--user',
        'enable',
        '--now',
        'workmanager-1234abcd.timer',
      ]);
      expect(commands.listTimers(), <String>[
        'systemctl',
        '--user',
        'list-timers',
        '--all',
        '--no-legend',
        '--plain',
      ]);
      expect(commands.stopAllTimers(), <String>[
        'systemctl',
        '--user',
        'stop',
        'workmanager-*.timer',
      ]);
      expect(commands.stopAllServices(), <String>[
        'systemctl',
        '--user',
        'stop',
        'workmanager-*.service',
      ]);
      expect(commands.disableAllTimers(), <String>[
        'systemctl',
        '--user',
        'disable',
        'workmanager-*.timer',
      ]);
      expect(commands.resetFailedAll(), <String>[
        'systemctl',
        '--user',
        'reset-failed',
        'workmanager-*',
      ]);
    });
  });

  group('SystemdUnitFiles.quoteExecArgument', () {
    test('passes plain arguments through unchanged', () {
      expect(SystemdUnitFiles.quoteExecArgument('--background-task'),
          '--background-task');
      expect(SystemdUnitFiles.quoteExecArgument('/opt/app/example'),
          '/opt/app/example');
    });

    test('quotes arguments with spaces', () {
      expect(SystemdUnitFiles.quoteExecArgument('my task'), '"my task"');
    });

    test('escapes quotes and backslashes inside quotes', () {
      expect(SystemdUnitFiles.quoteExecArgument('a"b'), r'"a\"b"');
      expect(SystemdUnitFiles.quoteExecArgument(r'a\b'), r'"a\\b"');
    });
  });
}
