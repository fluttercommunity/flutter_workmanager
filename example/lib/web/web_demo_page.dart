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
/// background-execution log and a two-way "worker chat" (page <-> background
/// worker via postMessage), and offers a PWA install button so Periodic
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
  final List<_ChatLine> _chat = <_ChatLine>[];
  final TextEditingController _messageController = TextEditingController();
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    InstallGlue.listen();
    WorkmanagerWeb().backgroundEvents.listen(_onEvent);
    WorkmanagerWeb().workerMessages.listen(_onWorkerMessage);
    _initialize();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
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

  void _onWorkerMessage(Object? payload) {
    if (!mounted) {
      return;
    }
    setState(() {
      _chat.add(_ChatLine(text: _formatWorkerMessage(payload), fromWorker: true));
    });
  }

  /// Sends a structured message to the background worker (see
  /// `handleWorkerMessage` in `background_tasks.dart`).
  void _sendToWorker(Map<String, Object?> message) {
    setState(() {
      _chat.add(_ChatLine(text: _formatSentMessage(message), fromWorker: false));
    });
    WorkmanagerWeb().sendMessageToWorker(message);
  }

  void _sendFreeText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _messageController.clear();
    _sendToWorker(<String, Object?>{'op': 'text', 'text': trimmed});
  }

  Future<void> _registerOneOff() async {
    await WorkmanagerWeb().registerOneOffTask(
      _oneOffTask,
      _oneOffTask,
      inputData: <String, dynamic>{
        'via': 'oneOff',
        'ticker': 'btc',
        'threshold': 58000,
      },
      initialDelay: const Duration(seconds: 5),
    );
  }

  Future<void> _registerPeriodic() async {
    await WorkmanagerWeb().registerPeriodicTask(
      _periodicTask,
      _periodicTask,
      inputData: <String, dynamic>{
        'via': 'periodic',
        'ticker': 'eth',
        'threshold': 2400,
      },
      frequency: const Duration(minutes: 15),
    );
  }

  Future<void> _triggerNow() async {
    await WorkmanagerWeb().triggerTask(
      _oneOffTask,
      inputData: <String, dynamic>{
        'via': 'manual trigger',
        'ticker': 'btc',
        'threshold': 60000,
      },
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
                      : 'Tasks run in a Web Worker (page open) or the Service '
                          'Worker (page closed, via Periodic Sync / Push) and '
                          'results are replayed from IndexedDB on load. The '
                          'chat below talks to the worker over postMessage. '
                          'Install the PWA for real background sync.',
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
          _buildChatPanel(context),
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

  Widget _buildChatPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Worker chat — page ↔ background worker (postMessage)',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Container(
            height: 170,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _chat.isEmpty
                ? const Center(
                    child: Text(
                      'Send a message or tap a suggestion below.\n'
                      'The worker replies from a separate thread.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(6),
                    itemCount: _chat.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _ChatBubble(line: _chat[index]);
                    },
                  ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _messageController,
                  onSubmitted: _sendFreeText,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Type a message for the worker…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: _initializing
                    ? null
                    : () => _sendFreeText(_messageController.text),
                icon: const Icon(Icons.send),
                tooltip: 'Send to worker',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              ActionChip(
                label: const Text('Watch BTC (<\$58k)'),
                onPressed: _initializing
                    ? null
                    : () => _sendToWorker(<String, Object?>{
                          'op': 'watch',
                          'ticker': 'btc',
                          'threshold': 58000,
                        }),
              ),
              ActionChip(
                label: const Text('Watch ETH (<\$2.5k)'),
                onPressed: _initializing
                    ? null
                    : () => _sendToWorker(<String, Object?>{
                          'op': 'watch',
                          'ticker': 'eth',
                          'threshold': 2500,
                        }),
              ),
              ActionChip(
                label: const Text('Stop watch'),
                onPressed: _initializing
                    ? null
                    : () => _sendToWorker(<String, Object?>{'op': 'stop'}),
              ),
              ActionChip(
                label: const Text('Background check (task)'),
                onPressed: _initializing
                    ? null
                    : () => _sendToWorker(<String, Object?>{
                          'op': 'check',
                          'ticker': 'ada',
                        }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatSentMessage(Map<String, Object?> message) {
    final op = message['op'];
    switch (op) {
      case 'watch':
        final threshold = (message['threshold'] as num?)?.toDouble();
        return '📨 watch ${message['ticker']}'
            '${threshold == null ? '' : ' (< \$${threshold.toStringAsFixed(0)})'}';
      case 'stop':
        return '📨 stop';
      case 'text':
        return '📨 ${message['text']}';
      case 'check':
        return '📨 background check ${message['ticker']}';
      default:
        return '📨 $message';
    }
  }

  String _formatWorkerMessage(Object? payload) {
    if (payload is! Map) {
      return '${payload ?? '(empty)'}';
    }
    final kind = payload['kind'];
    final ticker = payload['ticker'] as String?;
    final price = (payload['price'] as num?)?.toDouble();
    final priceText = price == null ? '' : '\$${price.toStringAsFixed(2)}';
    switch (kind) {
      case 'watching':
        final threshold = (payload['threshold'] as num?)?.toDouble();
        return '👀 watching $ticker${threshold == null ? '' : ' · alert < \$${threshold.toStringAsFixed(0)}'}';
      case 'tick':
        return '📈 $ticker $priceText';
      case 'alert':
        final threshold = (payload['threshold'] as num?)?.toDouble();
        return '🚨 $ticker $priceText below '
            '\$${threshold?.toStringAsFixed(0) ?? '?'} — stopping';
      case 'stopped':
        return '🛑 watch stopped';
      case 'echo':
        return '↩︎ ${payload['text']}';
      case 'task-start':
        return '▶ background check: $ticker…';
      case 'task-done':
        final below = payload['below'] == true;
        return '✅ $ticker $priceText${below ? ' · BELOW threshold' : ' · ok'}';
      default:
        return '$payload';
    }
  }
}

class _ChatLine {
  const _ChatLine({required this.text, required this.fromWorker});

  final String text;
  final bool fromWorker;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.line});

  final _ChatLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = line.fromWorker
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.primaryContainer;
    return Align(
      alignment: line.fromWorker ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(line.text, style: const TextStyle(fontSize: 12)),
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
