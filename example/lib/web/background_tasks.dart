// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

// IMPORTANT: this file must stay Flutter-free (no `package:flutter/...`
// imports). It is compiled with plain `dart compile js` into
// `web/background.dart.js` and executed both by the in-page Web Worker and by
// the Service Worker, neither of which can run the Flutter engine.

import 'dart:async';

import 'package:workmanager_web/execution.dart';

import 'web_glue.dart';

/// Dispatcher used on the web: wired into the compiled worker bundle
/// (`web/background.dart`) and passed to `WorkmanagerWeb().initialize(...)` on
/// the page (fallback path).
@pragma('vm:entry-point')
void webCallbackDispatcher() {
  WorkmanagerExecution.instance.executeTask(handleWebBackgroundTask);
  WorkmanagerExecution.instance.messageHandler = handleWorkerMessage;
}

// ---------------------------------------------------------------------------
// Use case: a simulated "weather watch".
//
// The demo simulates a temperature feed so it stays self-contained (no
// network, no API key). The same shape applies to any real background work:
//
// * the page sends a message to the worker       -> messageHandler runs in
//   the Web Worker (off the main thread),
// * the worker pushes updates back              -> sendToPage surfaces them
//   on `WorkmanagerWeb.workerMessages`,
// * background tasks (also while the page is closed, via the Service Worker)
//   run the same handler and their results are replayed into the event log.
// ---------------------------------------------------------------------------

/// Simulated baseline temperature per city, in °C.
const Map<String, double> _baseTemps = <String, double>{
  'cardiff': 11.0,
  'taipei': 26.0,
};

Timer? _watchTimer;

/// Handler for free-form messages sent by the page with
/// `WorkmanagerWeb().sendMessageToWorker(...)`.
///
/// Messages:
/// * `{'op': 'watch', 'city': 'cardiff', 'threshold': 5.0}` — start pushing
///   simulated temperatures every few seconds; stops itself when the
///   temperature drops below [threshold].
/// * `{'op': 'stop'}` — stop the current watch.
/// * `{'op': 'check', 'city': ..., 'threshold': ...}` — run a one-off
///   background check (same logic as the task path).
/// * `{'op': 'text', 'text': ...}` — echo arbitrary text back.
void handleWorkerMessage(Object? payload) {
  if (payload is! Map) {
    return;
  }
  final op = payload['op'];
  switch (op) {
    case 'watch':
      final city = (payload['city'] as String?)?.toLowerCase() ?? 'cardiff';
      final threshold = (payload['threshold'] as num?)?.toDouble();
      _watchTimer?.cancel();
      _post(<String, Object?>{
        'kind': 'watching',
        'city': city,
        'threshold': threshold,
      });
      _postTick(city, threshold);
      _watchTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _postTick(city, threshold),
      );
    case 'stop':
      _watchTimer?.cancel();
      _watchTimer = null;
      _post(<String, Object?>{'kind': 'stopped'});
    case 'check':
      // One-off background check on demand (same logic as the task path).
      final city = (payload['city'] as String?)?.toLowerCase() ?? 'cardiff';
      final threshold = (payload['threshold'] as num?)?.toDouble();
      _post(<String, Object?>{'kind': 'task-start', 'city': city});
      final tempC = _simulatedTemp(city);
      final below = threshold != null && tempC < threshold;
      _post(<String, Object?>{
        'kind': 'task-done',
        'city': city,
        'tempC': tempC,
        'below': below,
      });
    case 'text':
      _post(<String, Object?>{'kind': 'echo', 'text': payload['text']});
  }
}

void _postTick(String city, double? threshold) {
  final tempC = _simulatedTemp(city);
  final below = threshold != null && tempC < threshold;
  _post(<String, Object?>{
    'kind': below ? 'alert' : 'tick',
    'city': city,
    'tempC': tempC,
    'threshold': threshold,
  });
  if (below) {
    _watchTimer?.cancel();
    _watchTimer = null;
  }
}

/// Sends a free-form message back to the page (if a page is reachable).
void _post(Object? payload) {
  WorkmanagerExecution.instance.sendToPage?.call(payload);
}

/// Deterministic, time-varying simulated temperature: stable within a 30s
/// bucket so consecutive ticks change, but the demo never needs the network.
double _simulatedTemp(String city) {
  final base = _baseTemps[city] ?? 15.0;
  final bucket = DateTime.now().millisecondsSinceEpoch ~/ 30000;
  final hash = _hash('$city:$bucket');
  final wiggle = (hash % 1000) / 1000 * 0.10 - 0.05; // ±5%
  return base * (1 + wiggle);
}

int _hash(String input) {
  var hash = 0;
  for (final codeUnit in input.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }
  return hash;
}

/// Pure-Dart background task handler.
///
/// With `inputData['city']` it behaves like a background "temperature
/// check": it pushes progress messages to the page while running and returns
/// the temperature + alert state as the task result. The result is recorded
/// by the runtime: when the page is open it appears in the event log
/// immediately; when the Service Worker ran the task while the page was
/// closed, it is replayed on the next page load.
Future<bool> handleWebBackgroundTask(
  String taskName,
  Map<String, dynamic>? inputData,
) async {
  final input = inputData;
  if (input != null && input['fail'] == true) {
    return false;
  }
  final city = (input?['city'] as String?)?.toLowerCase() ?? 'cardiff';
  final threshold = (input?['threshold'] as num?)?.toDouble();

  // A small CPU loop so the Web Worker's parallel execution is observable:
  // the UI stays responsive while this runs off the main thread.
  // ignore: unused_local_variable
  var checksum = 0;
  for (var i = 0; i < 2000000; i++) {
    checksum += i;
  }

  _post(<String, Object?>{
    'kind': 'task-start',
    'city': city,
    'threshold': threshold,
  });
  final tempC = _simulatedTemp(city);
  final below = threshold != null && tempC < threshold;
  _post(<String, Object?>{
    'kind': 'task-done',
    'city': city,
    'tempC': tempC,
    'below': below,
  });
  _notify(
    below
        ? '❄️ $city below the alert threshold'
        : 'Temperature check: ${_capitalize(city)}',
    '${tempC.toStringAsFixed(1)}°C — '
    '${below ? 'below the alert threshold' : 'all good'}',
  );
  // The task result itself stays a plain success/failure bool; the
  // temperature detail is delivered via the chat messages above.
  return true;
}

/// Shows a browser notification when a background task finishes inside the
/// Service Worker (i.e. while the page is closed). The dedicated Web Worker
/// has no `registration`, so there the page shows the notification instead.
void _notify(String title, String body) {
  showServiceWorkerNotification(title, body);
}

String _capitalize(String input) {
  if (input.isEmpty) {
    return input;
  }
  return input[0].toUpperCase() + input.substring(1);
}
