// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:workmanager_web/workmanager_web.dart';

import 'background_tasks.dart';
import 'install_glue.dart';

const String _oneOffTask = 'dev.fluttercommunity.workmanagerExample.webOneOff';
const String _periodicTask =
    'dev.fluttercommunity.workmanagerExample.webPeriodic';

/// Web-only demo: registers tasks through [WorkmanagerWeb], shows a live
/// background-execution log and offers a PWA install button so Periodic
/// Background Sync can be tested.
class WebDemoApp extends StatelessWidget {
  const WebDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Workmanager Web Demo',
      home: WebDemoPage(),
    );
  }
}

class WebDemoPage extends StatefulWidget {
  const WebDemoPage({super.key});

  @override
  State<WebDemoPage> createState() => _WebDemoPageState();
}

class _WebDemoPageState extends State<WebDemoPage> {
  final List<WorkmanagerWebEvent> _events = <WorkmanagerWebEvent>[];
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    InstallGlue.listen();
    WorkmanagerWeb().backgroundEvents.listen(_onEvent);
    _initialize();
  }

  Future<void> _initialize() async {
    await WorkmanagerWeb().initialize(
      webCallbackDispatcher,
      dispatcherUrl: WorkmanagerWeb.defaultDispatcherUrl,
    );
    if (mounted) {
      setState(() => _initializing = false);
    }
  }

  void _onEvent(WorkmanagerWebEvent event) {
    if (!mounted) {
      return;
    }
    setState(() => _events.insert(0, event));
  }

  Future<void> _registerOneOff() async {
    await WorkmanagerWeb().registerOneOffTask(
      _oneOffTask,
      _oneOffTask,
      inputData: <String, dynamic>{'via': 'oneOff'},
      initialDelay: const Duration(seconds: 5),
    );
  }

  Future<void> _registerPeriodic() async {
    await WorkmanagerWeb().registerPeriodicTask(
      _periodicTask,
      _periodicTask,
      inputData: <String, dynamic>{'via': 'periodic'},
      frequency: const Duration(minutes: 15),
    );
  }

  Future<void> _triggerNow() async {
    await WorkmanagerWeb().triggerTask(
      _oneOffTask,
      inputData: <String, dynamic>{'via': 'manual trigger'},
    );
  }

  Future<void> _cancelAll() async {
    await WorkmanagerWeb().cancelAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workmanager Web (experimental)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _initializing
                      ? 'Initializing…'
                      : 'Ready. Open DevTools → Application → Service Workers '
                          'to trigger "periodicsync" / "Push" and watch this '
                          'panel. Install the PWA for real background sync.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton(
                      onPressed: _initializing ? null : _registerOneOff,
                      child: const Text('One-off (5 s)'),
                    ),
                    FilledButton(
                      onPressed: _initializing ? null : _registerPeriodic,
                      child: const Text('Periodic (15 min)'),
                    ),
                    FilledButton.tonal(
                      onPressed: _initializing ? null : _triggerNow,
                      child: const Text('Run now'),
                    ),
                    OutlinedButton(
                      onPressed: _initializing ? null : _cancelAll,
                      child: const Text('Cancel all'),
                    ),
                    if (InstallGlue.canPrompt)
                      FilledButton.icon(
                        onPressed: InstallGlue.promptInstall,
                        icon: const Icon(Icons.download),
                        label: const Text('Install PWA'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _events.isEmpty
                ? const Center(
                    child: Text(
                      'No background events yet.\n'
                      'Events executed by the Web Worker, the Service Worker '
                      '(page closed) and replayed on load appear here.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: _events.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _EventTile(event: _events[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final WorkmanagerWebEvent event;

  @override
  Widget build(BuildContext context) {
    final time = '${event.timestamp.hour.toString().padLeft(2, '0')}:'
        '${event.timestamp.minute.toString().padLeft(2, '0')}:'
        '${event.timestamp.second.toString().padLeft(2, '0')}';
    return ListTile(
      leading: Icon(_iconFor(event.state), color: _colorFor(event.state)),
      title: Text(
        '${event.taskName ?? '(no task)'} · ${event.source}',
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        '[$time] ${event.message ?? event.state}'
        '${event.result == null ? '' : '\nresult: $event.result'}',
        style: const TextStyle(fontSize: 12),
      ),
      isThreeLine: event.result != null,
      dense: true,
    );
  }

  IconData _iconFor(String state) {
    switch (state) {
      case 'executed':
        return Icons.check_circle_outline;
      case 'relayed':
        return Icons.swap_horiz;
      case 'missed':
      case 'error':
        return Icons.error_outline;
      case 'warning':
        return Icons.warning_amber;
      default:
        return Icons.info_outline;
    }
  }

  Color _colorFor(String state) {
    switch (state) {
      case 'executed':
        return Colors.green;
      case 'relayed':
        return Colors.blue;
      case 'missed':
      case 'error':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }
}
