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

/// Web-only demo: registers tasks through [WorkmanagerWeb], shows a two-way
/// "worker chat" (page <-> background worker via postMessage) and a task log
/// with background-execution events (incl. Service Worker replay).
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
  bool _periodicRegistered = false;

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
    // Register the demo task automatically so the demo works with zero
    // setup; use DevTools -> Application -> Periodic Background Sync to
    // trigger it while the page is closed.
    await WorkmanagerWeb().registerPeriodicTask(
      _periodicTask,
      _periodicTask,
      inputData: <String, dynamic>{'ticker': 'eth', 'threshold': 2400},
      frequency: const Duration(minutes: 15),
    );
    if (mounted) {
      setState(() {
        _initializing = false;
        _periodicRegistered = true;
      });
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
      _chat.add(
          _ChatLine(text: _formatWorkerMessage(payload), fromWorker: true));
    });
  }

  /// Sends a structured message to the background worker (see
  /// `handleWorkerMessage` in `background_tasks.dart`).
  void _sendToWorker(Map<String, Object?> message) {
    setState(() {
      _chat
          .add(_ChatLine(text: _formatSentMessage(message), fromWorker: false));
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

  Future<void> _runCheckNow() async {
    await WorkmanagerWeb().triggerTask(
      _oneOffTask,
      inputData: <String, dynamic>{'ticker': 'btc', 'threshold': 60000},
    );
  }

  Future<void> _cancelAll() async {
    await WorkmanagerWeb().cancelAll();
    if (mounted) {
      setState(() => _periodicRegistered = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workmanager Web Demo'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Worker chat'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Task log'),
            ],
          ),
          actions: <Widget>[
            PopupMenuButton<String>(
              enabled: !_initializing,
              onSelected: (String value) {
                if (value == 'cancel') {
                  _cancelAll();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'cancel',
                  child: Text('Cancel all tasks'),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            _buildStatusStrip(context),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _buildChatTab(context),
                  _buildTaskLogTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusStrip(BuildContext context) {
    final theme = Theme.of(context);
    final ready = !_initializing && _periodicRegistered;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(
            ready ? Icons.check_circle : Icons.hourglass_top,
            size: 16,
            color: ready ? Colors.green : theme.colorScheme.outline,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _initializing
                  ? 'Starting worker…'
                  : _periodicRegistered
                      ? 'Worker online · price check scheduled every 15 min '
                          '(runs in the background via Service Worker)'
                      : 'Worker online · no tasks scheduled',
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Talk to the worker — it replies from a separate thread '
            '(postMessage). Try a watch, or type anything.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _chat.isEmpty
                  ? const Center(
                      child: Text(
                        'Messages appear here.\n'
                        'Tap "Watch BTC" below to see live replies.',
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
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _messageController,
                  onSubmitted: _sendFreeText,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Message the worker…',
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              ActionChip(
                avatar: const Icon(Icons.trending_up, size: 16),
                label: const Text('Watch BTC'),
                onPressed: _initializing
                    ? null
                    : () => _sendToWorker(<String, Object?>{
                          'op': 'watch',
                          'ticker': 'btc',
                          'threshold': 58000,
                        }),
              ),
              ActionChip(
                avatar: const Icon(Icons.trending_up, size: 16),
                label: const Text('Watch ETH'),
                onPressed: _initializing
                    ? null
                    : () => _sendToWorker(<String, Object?>{
                          'op': 'watch',
                          'ticker': 'eth',
                          'threshold': 2500,
                        }),
              ),
              ActionChip(
                avatar: const Icon(Icons.stop, size: 16),
                label: const Text('Stop'),
                onPressed: _initializing
                    ? null
                    : () => _sendToWorker(<String, Object?>{'op': 'stop'}),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskLogTab(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: _initializing ? null : _runCheckNow,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run check now'),
              ),
              if (InstallGlue.canPrompt)
                FilledButton.icon(
                  onPressed: InstallGlue.promptInstall,
                  icon: const Icon(Icons.download),
                  label: const Text('Install app'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _events.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No background events yet.\n\n'
                    'Events executed by the Web Worker (page open) or the '
                    'Service Worker (page closed, via Periodic Background '
                    'Sync / Push) appear here, replayed from IndexedDB on '
                    'load.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
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
