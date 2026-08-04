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

/// High-contrast status colors, readable on white.
const Color _okGreen = Color(0xFF1E8E3E);
const Color _alertRed = Color(0xFFC5221F);
const Color _warnOrange = Color(0xFFB06000);
const Color _infoBlue = Color(0xFF174EA6);
const Color _mutedGrey = Color(0xFF5B6670);

/// Web-only demo: registers tasks through [WorkmanagerWeb], shows a two-way
/// "worker chat" (page <-> background worker via postMessage) and a task log
/// with background-execution events (incl. Service Worker replay).
///
/// The simulated use case is a "weather watch": the page asks the worker to
/// watch a city, and the worker streams simulated temperatures, alerting when
/// the temperature drops below a threshold. Simulated, so the demo needs no
/// network and no API keys.
class WebDemoApp extends StatelessWidget {
  const WebDemoApp({super.key});

  static final ThemeData _theme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B57D0),
    ).copyWith(
      primary: const Color(0xFF0B57D0),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD3E3FD),
      onPrimaryContainer: const Color(0xFF001B3F),
      surface: Colors.white,
      onSurface: const Color(0xFF111111),
      onSurfaceVariant: const Color(0xFF1F1F1F),
      outline: _mutedGrey,
      outlineVariant: const Color(0xFFB0B8BF),
      surfaceContainerHighest: const Color(0xFFE1E5E8),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Color(0xFF111111),
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111111),
      ),
      bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF111111)),
      bodyMedium: TextStyle(fontSize: 15, color: Color(0xFF111111)),
      bodySmall: TextStyle(fontSize: 14, color: Color(0xFF1F1F1F)),
      labelLarge: TextStyle(fontSize: 14, color: Color(0xFF111111)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0B57D0),
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFB0B8BF)),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workmanager Web Demo',
      theme: _theme,
      home: const WebDemoPage(),
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
      inputData: <String, dynamic>{'city': 'taipei', 'threshold': 20.0},
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
      inputData: <String, dynamic>{'city': 'cardiff', 'threshold': 5.0},
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
            size: 18,
            color: ready ? _okGreen : _mutedGrey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _initializing
                  ? 'Starting worker…'
                  : _periodicRegistered
                      ? 'Worker online · temperature check scheduled every '
                          '15 min (runs in the background via Service Worker)'
                      : 'Worker online · no tasks scheduled',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: const Color(0xFFF1F4F8),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFB0B8BF)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('How this demo works', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            const _InfoLine(
              icon: Icons.forum_outlined,
              iconColor: _infoBlue,
              text: 'Messaging — you talk to the background worker, which '
                  'runs on its own thread; it replies via postMessage '
                  '(this tab).',
            ),
            const SizedBox(height: 6),
            const _InfoLine(
              icon: Icons.play_circle_outline,
              iconColor: _okGreen,
              text: 'Background tasks — registered tasks run off the page: '
                  '"Run check now" fires one immediately, and one runs every '
                  '15 min. Results appear in the Task log tab.',
            ),
            const SizedBox(height: 6),
            const _InfoLine(
              icon: Icons.cloud_outlined,
              iconColor: _warnOrange,
              text: 'Service Worker — install the app as a PWA and tasks '
                  'also run while the page is closed; their results are '
                  'replayed into the Task log when you reopen the page.',
            ),
            const SizedBox(height: 10),
            Text(
              'Try it: tap "Watch Cardiff" below, type any message, or run '
              'a check in the Task log tab. All data is simulated — no '
              'network needed.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _buildHowItWorksCard(context),
        const SizedBox(height: 12),
        Container(
          height: 220,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFB0B8BF)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: _chat.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Messages appear here — yours and the worker\'s '
                      'replies.\n\nTap "Watch Cardiff" to see a live '
                      'conversation, or just type anything.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: _chat.length,
                  itemBuilder: (BuildContext context, int index) {
                    return _ChatBubble(line: _chat[index]);
                  },
                ),
        ),
        const SizedBox(height: 10),
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
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _initializing
                  ? null
                  : () => _sendFreeText(_messageController.text),
              icon: const Icon(Icons.send),
              tooltip: 'Send to worker',
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            ActionChip(
              avatar: const Icon(Icons.thermostat, size: 18),
              label: const Text('Watch Cardiff'),
              onPressed: _initializing
                  ? null
                  : () => _sendToWorker(<String, Object?>{
                        'op': 'watch',
                        'city': 'cardiff',
                        'threshold': 5.0,
                      }),
            ),
            ActionChip(
              avatar: const Icon(Icons.thermostat, size: 18),
              label: const Text('Watch Taipei'),
              onPressed: _initializing
                  ? null
                  : () => _sendToWorker(<String, Object?>{
                        'op': 'watch',
                        'city': 'taipei',
                        'threshold': 20.0,
                      }),
            ),
            ActionChip(
              avatar: const Icon(Icons.stop, size: 18),
              label: const Text('Stop'),
              onPressed: _initializing
                  ? null
                  : () => _sendToWorker(<String, Object?>{'op': 'stop'}),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaskLogTab(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            'Event states: executed = task ran · relayed = message routed · '
            'missed/error = failure · warning = retried. Events from runs '
            'while the page was closed are replayed here on load.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _events.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No background events yet.\n\n'
                    'Events appear whenever a registered task runs: press '
                    '"Run check now" to fire one immediately. While the page '
                    'is open, tasks run in the Web Worker; once the app is '
                    'installed as a PWA, they also run in the Service Worker '
                    'when the page is closed.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
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
        final city = _capitalize(message['city'] as String? ?? '?');
        return '📨 watch $city'
            '${threshold == null ? '' : ' (alert < ${threshold.toStringAsFixed(0)}°C)'}';
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
    final city = _capitalize(payload['city'] as String? ?? '?');
    final tempC = (payload['tempC'] as num?)?.toDouble();
    final tempText = tempC == null ? '' : '${tempC.toStringAsFixed(1)}°C';
    switch (kind) {
      case 'watching':
        final threshold = (payload['threshold'] as num?)?.toDouble();
        return '👀 watching $city'
            '${threshold == null ? '' : ' · alert below ${threshold.toStringAsFixed(0)}°C'}';
      case 'tick':
        return '🌡️ $city $tempText';
      case 'alert':
        final threshold = (payload['threshold'] as num?)?.toDouble();
        return '🚨 $city $tempText below '
            '${threshold?.toStringAsFixed(0) ?? '?'}°C — stopping';
      case 'stopped':
        return '🛑 watch stopped';
      case 'echo':
        return '↩︎ ${payload['text']}';
      case 'task-start':
        return '▶ background check: $city…';
      case 'task-done':
        final below = payload['below'] == true;
        return '✅ $city $tempText${below ? ' · BELOW threshold' : ' · ok'}';
      default:
        return '$payload';
    }
  }

  static String _capitalize(String input) {
    if (input.isEmpty) {
      return input;
    }
    return input[0].toUpperCase() + input.substring(1);
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.iconColor, required this.text});

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
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
    final fromWorker = line.fromWorker;
    final Color background =
        fromWorker ? Colors.white : theme.colorScheme.primaryContainer;
    final Color foreground =
        fromWorker ? const Color(0xFF111111) : theme.colorScheme.onPrimaryContainer;
    final BoxBorder border = Border.all(
      color: fromWorker ? const Color(0xFFB0B8BF) : Colors.transparent,
    );
    return Align(
      alignment: fromWorker ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: background,
          border: border,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          line.text,
          style: TextStyle(fontSize: 14, height: 1.35, color: foreground),
        ),
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
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '[$time] ${event.message ?? event.state}'
        '${event.result == null ? '' : '\nresult: $event.result'}',
        style: const TextStyle(fontSize: 13, height: 1.3),
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
        return _okGreen;
      case 'relayed':
        return _infoBlue;
      case 'missed':
      case 'error':
        return _alertRed;
      case 'warning':
        return _warnOrange;
      default:
        return _mutedGrey;
    }
  }
}
