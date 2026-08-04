// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

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
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Color(0xFFD3E3FD),
      indicatorColor: Colors.white,
      labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 14),
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
  bool _notificationsGranted = false;
  bool _appInstalled = false;

  @override
  void initState() {
    super.initState();
    InstallGlue.listen();
    _appInstalled = InstallGlue.installed;
    InstallGlue.onInstalled = () {
      if (mounted) {
        setState(() => _appInstalled = true);
      }
    };
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
    // The foreground stays in sync with background runs: every executed
    // task also lands in the chat, including runs that happened while the
    // page was closed (replayed from the IndexedDB queue on load).
    if (event.state == 'executed') {
      _chat.add(_ChatLine(
        text: '↩️ background: ${event.taskName ?? 'task'} finished'
            '${event.result == null ? '' : ' → result: $event.result'}'
            ' (${event.source})',
        fromWorker: true,
      ));
      if (_notificationsGranted) {
        _showPageNotification(
          'Workmanager demo',
          '${event.taskName ?? 'Background task'} finished'
          '${event.result == null ? '' : ' — result: $event.result'}.',
        );
      }
    }
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

  /// Installs the demo as a PWA. Shows the browser's install prompt when
  /// available; otherwise explains how to install (address-bar icon).
  Future<void> _installApp() async {
    final installed = await InstallGlue.promptInstall();
    if (installed) {
      if (mounted) {
        setState(() => _appInstalled = true);
      }
      return;
    }
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('How to install the demo'),
        content: const Text(
          'Chrome hasn\'t offered the install prompt yet. You can:\n\n'
          '• Tap the install icon (⊕) in the address bar.\n'
          '• Use the demo for a moment, then tap "Install the app" again.\n'
          '• Installation requires localhost or HTTPS.\n\n'
          'Installing adds the app to your device like a native app — '
          'that is what lets tasks run with no tab open.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  /// Requests the Web Notifications permission (must be called from a user
  /// gesture in most browsers).
  Future<void> _requestNotifications() async {
    final notification = globalContext['Notification'];
    if (notification == null) {
      return;
    }
    final notificationObj = notification as JSObject;
    final permission = notificationObj['permission']?.dartify();
    if (permission == 'granted') {
      setState(() => _notificationsGranted = true);
      return;
    }
    if (permission == 'denied') {
      return;
    }
    final result = await (notificationObj
            .callMethod('requestPermission'.toJS) as JSPromise<JSAny?>)
        .toDart;
    if (!mounted) {
      return;
    }
    setState(() => _notificationsGranted = result?.dartify() == 'granted');
  }

  /// Shows a page-side notification (only used when the page is open; the
  /// Service Worker shows its own when the page is closed — see
  /// `_notify` in `background_tasks.dart`).
  void _showPageNotification(String title, String body) {
    final notification = globalContext['Notification'];
    if (notification == null) {
      return;
    }
    (notification as JSFunction).callAsConstructor<JSObject>(
      title.toJS,
      <String, Object?>{'body': body}.jsify(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workmanager Web Demo'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Task log'),
              Tab(icon: Icon(Icons.flag_outlined), text: 'Guide'),
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
                  _buildGuideTab(context),
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

  Widget _buildChatTab(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F4F8),
            border: Border.all(color: const Color(0xFFB0B8BF)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'This tab talks to the background worker, which runs on its own '
            'thread — it replies via postMessage. Tap a chip below or type '
            'any message. For the full walkthrough (notifications, closing '
            'the tab, Service Worker), see the Guide tab.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
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
                        'threshold': 10.9,
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
                        'threshold': 24.0,
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
              if (_notificationsGranted)
                const _NotificationStatus()
              else
                FilledButton.tonalIcon(
                  onPressed: _requestNotifications,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Allow notifications'),
                ),
              if (_appInstalled)
                const _InstalledStatus()
              else
                FilledButton.icon(
                  onPressed: _installApp,
                  icon: const Icon(Icons.download),
                  label: const Text('Install the app'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            'This log is the persistent background queue (single source of '
            'truth): executed = task ran · relayed = message routed · '
            'missed/error = failure · warning = retried. Runs from when the '
            'page was closed are replayed here on load.',
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

  Widget _buildGuideTab(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F4F8),
            border: Border.all(color: const Color(0xFFB0B8BF)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'What this demo tests\n\n'
            '1. Messaging — the page and the background worker talk over '
            'postMessage (Chat tab).\n'
            '2. Background tasks — one-off and periodic tasks execute off '
            'the page (Task log tab).\n'
            '3. Service Worker — with the app installed, tasks keep running '
            'even when no tab is open, and notify you when they finish.\n'
            '4. Single source of truth — every background run is recorded in '
            'a persistent queue (Task log) and replayed when you reopen the '
            'app, so the foreground always sees what the background did.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 16),
        Text('Try it — step by step', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        const _GuideStep(
          number: '1',
          title: 'Talk to the worker',
          body: 'Open the Chat tab and tap "Watch Cardiff", or type any '
              'message. The worker answers from its own thread.',
        ),
        const _GuideStep(
          number: '2',
          title: 'Allow notifications',
          body: 'Tap "Allow notifications" on the Task log tab. Finished '
              'tasks will then ping you — even with the tab closed.',
        ),
        const _GuideStep(
          number: '3',
          title: 'Install the app (as a PWA)',
          body: 'Installing adds the demo to your device like a native app '
              '— that is what allows tasks to run with no tab open. Use the '
              'button below, or the install icon (⊕) in Chrome\'s address '
              'bar.',
        ),
        Padding(
          padding: const EdgeInsets.only(left: 36, bottom: 8),
          child: _appInstalled
              ? const _InstalledStatus()
              : FilledButton.icon(
                  onPressed: _installApp,
                  icon: const Icon(Icons.download),
                  label: const Text('Install the app'),
                ),
        ),
        const _GuideStep(
          number: '4',
          title: 'Close this tab — yes, really',
          body: 'Close the tab. The Service Worker keeps running your '
              'registered tasks in the background.',
        ),
        const _GuideStep(
          number: '5',
          title: 'Trigger a background check',
          body: 'In DevTools (F12) → Application → Periodic Background '
              'Sync, select the task and press "Sync now". A notification '
              'appears even though the tab is closed.',
        ),
        const _GuideStep(
          number: '6',
          title: 'Reopen the app',
          body: 'Results from closed-page runs are replayed from the '
              'persistent queue (IndexedDB) into the Task log — and the '
              'chat shows a "background: …" line for each run, so the '
              'foreground always reflects what the background did.',
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3D6),
            border: Border.all(color: const Color(0xFFB06000)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Developer note: when running via `flutter run -d chrome`, use a '
            'full reload after code changes — hot restart is buggy on web '
            '(can throw "disposed EngineFlutterView" errors; a page refresh '
            'fixes it).',
            style: theme.textTheme.bodySmall,
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

class _InstalledStatus extends StatelessWidget {
  const _InstalledStatus();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.check_circle, size: 18, color: _okGreen),
        const SizedBox(width: 6),
        Text('App installed', style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _NotificationStatus extends StatelessWidget {
  const _NotificationStatus();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.notifications_active, size: 18, color: _okGreen),
        const SizedBox(width: 6),
        Text('Notifications on', style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.number, required this.title, required this.body});

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF0B57D0),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
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
