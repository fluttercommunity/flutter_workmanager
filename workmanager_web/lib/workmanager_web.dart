// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

import 'execution.dart';
import 'src/browser_glue.dart';
import 'src/registrar.dart';
import 'src/worker_protocol.dart';

export 'execution.dart';

/// Callback invoked when a running background task is stopped by the platform
/// before it finished.
///
/// Accepted for API parity with the native plugin; web browsers never report
/// a stop reason, so this handler is never invoked on web.
typedef BackgroundTaskStoppedHandler = Future<void> Function(
    String taskName, StopReason stopReason);

/// A single background-execution event observed by [WorkmanagerWeb].
///
/// Events are emitted for executions that happen in the current page (Web
/// Worker or in-page fallback) and for executions recorded by the Service
/// Worker while the page was closed (replayed on the next load). The event
/// model is deliberately JSON-friendly so Service Worker records and Dart
/// events share one shape.
class WorkmanagerWebEvent {
  /// Creates an event.
  WorkmanagerWebEvent({
    required this.timestamp,
    required this.state,
    required this.source,
    this.uniqueName,
    this.taskName,
    this.result,
    this.message,
  });

  /// When the event happened.
  final DateTime timestamp;

  /// Outcome: `executed`, `relayed`, `missed`, `error`, `warning` or `info`.
  final String state;

  /// Where the execution originated: `page`, `webworker`, `timer`, `trigger`,
  /// `periodicsync`, `push`, `fetch`, `serviceworker` or `sw`.
  final String source;

  /// The unique name of the task, when known.
  final String? uniqueName;

  /// The task name, when known.
  final String? taskName;

  /// JSON-safe result of the execution, when any.
  final Object? result;

  /// Human-readable detail (for example an error description).
  final String? message;

  /// Converts the event to a JSON-compatible map.
  Map<String, Object?> toJson() => <String, Object?>{
        'ts': timestamp.millisecondsSinceEpoch,
        'state': state,
        'source': source,
        'uniqueName': uniqueName,
        'taskName': taskName,
        'result': result,
        'message': message,
      };

  /// Rebuilds an event from a decoded JSON map.
  factory WorkmanagerWebEvent.fromJson(Map<Object?, Object?> json) {
    final ts = json['ts'];
    return WorkmanagerWebEvent(
      timestamp: DateTime.fromMillisecondsSinceEpoch(ts is int ? ts : 0),
      state: (json['state'] as String?) ?? 'info',
      source: (json['source'] as String?) ?? 'sw',
      uniqueName: json['uniqueName'] as String?,
      taskName: json['taskName'] as String?,
      result: json['result'],
      message: json['message'] as String?,
    );
  }
}

/// Web implementation of [WorkmanagerPlatform].
///
/// Experimental. Web browsers cannot run Dart code at an exact wall-clock time
/// after the page is closed. [WorkmanagerWeb] approximates the workmanager
/// contract with three mechanisms:
///
/// * **Page open**: tasks execute in a dedicated Web Worker that runs the
///   compiled callback dispatcher (real parallel execution), falling back to
///   in-page execution when the bundle is missing.
/// * **Page closed — Periodic Background Sync** (Chromium): each periodic task
///   is registered with the browser; Chrome fires the Service Worker roughly
///   every `minInterval` (minimum 12 hours) once the PWA is installed and the
///   user has engagement. The Service Worker then runs the compiled dispatcher
///   bundle itself (via `importScripts`) and records the result.
/// * **Page closed — Web Push / fetch interception**: a push message or an
///   intercepted same-origin request can wake the Service Worker and trigger
///   the same path.
///
/// See the package README for the full list of honest limitations.
class WorkmanagerWeb extends WorkmanagerPlatform {
  WorkmanagerWeb._();

  static WorkmanagerWeb? _instance;

  /// Returns the shared instance.
  factory WorkmanagerWeb() => _instance ??= WorkmanagerWeb._();

  /// Registers this implementation as the default [WorkmanagerPlatform] for
  /// web. Called automatically by the generated plugin registrant.
  static void registerWith(Registrar? registrar) {
    WorkmanagerPlatform.instance = WorkmanagerWeb();
  }

  /// Default Service Worker script URL, relative to the app's base path.
  ///
  /// Copy `workmanager_service_worker.js` from this package's `web/` folder
  /// into your app's `web/` folder so it is served from this path.
  static const String defaultServiceWorkerUrl =
      '/workmanager_service_worker.js';

  /// Default URL of the compiled callback-dispatcher bundle.
  ///
  /// Compile your Flutter-free dispatcher entrypoint with
  /// `dart compile js -O2 web/background.dart -o web/background.dart.js` and
  /// commit the output next to your app's `web/` folder.
  static const String defaultDispatcherUrl = '/background.dart.js';

  /// Resolves a user-supplied or default script URL against the app's base
  /// URI, so deployments under a subpath (e.g. GitHub Pages project sites)
  /// resolve the defaults correctly while root deployments keep working.
  static String _resolveScriptUrl(String? url, String defaultUrl) {
    if (url != null) {
      return url;
    }
    var base = Uri.base;
    if (!base.path.endsWith('/')) {
      base = base.replace(path: '${base.path}/');
    }
    return base.resolve(defaultUrl.substring(1)).toString();
  }

  /// Chrome's minimum Periodic Background Sync interval.
  ///
  /// Frequencies below this are clamped before registering with the browser;
  /// the DevTools "Periodic Background Sync" panel can still trigger the event
  /// manually for testing.
  static const Duration minimumPeriodicSyncInterval = Duration(hours: 12);

  final StreamController<WorkmanagerWebEvent> _events =
      StreamController<WorkmanagerWebEvent>.broadcast();
  final StreamController<Object?> _workerMessages =
      StreamController<Object?>.broadcast();
  final Map<String, _RegisteredTask> _tasks = <String, _RegisteredTask>{};
  final Map<String, Timer> _oneOffTimers = <String, Timer>{};
  final Map<int, Completer<Object?>> _pendingWorkerRequests =
      <int, Completer<Object?>>{};

  Object? _worker;
  bool _workerFailed = false;
  bool _swAvailable = false;
  bool _initialized = false;
  bool _inPageDispatcherStarted = false;
  int _nextRequestId = 0;

  /// Live stream of background-execution events, including events replayed
  /// from the Service Worker after the page was closed.
  Stream<WorkmanagerWebEvent> get backgroundEvents => _events.stream;

  /// Live stream of free-form messages pushed by the background worker (or,
  /// on the in-page fallback path, by the dispatcher running in the page).
  ///
  /// Dispatcher code sends messages via
  /// `WorkmanagerExecution.instance.sendToPage`. Messages from a Service
  /// Worker execution are delivered to open pages via `clients.postMessage`;
  /// when no page is open they are dropped (persistent task results still
  /// arrive through [backgroundEvents] on the next load).
  Stream<Object?> get workerMessages => _workerMessages.stream;

  @override
  Future<void> initialize(
    Function callbackDispatcher, {
    @Deprecated(
        'Use WorkmanagerDebug handlers instead. This parameter has no effect.')
    bool isInDebugMode = false,
    String? serviceWorkerUrl,
    String? dispatcherUrl,
    bool useWebWorker = true,
  }) async {
    if (!kIsWeb) {
      throw UnsupportedError(
        'workmanager_web can only be used on web platforms. '
        'On native platforms use the `workmanager` package instead.',
      );
    }
    if (_initialized) {
      return;
    }
    _initialized = true;
    WorkmanagerExecution.instance.callbackDispatcher = callbackDispatcher;

    final resolvedDispatcherUrl =
        _resolveScriptUrl(dispatcherUrl, defaultDispatcherUrl);
    _emit(
      'info',
      'workmanager_web initialized. '
          'Dispatcher bundle: $resolvedDispatcherUrl.',
      source: 'page',
    );

    if (BrowserGlue.supportsServiceWorker) {
      await _initializeServiceWorker(
        _resolveScriptUrl(serviceWorkerUrl, defaultServiceWorkerUrl),
        resolvedDispatcherUrl,
      );
    } else {
      _emit(
        'warning',
        'Service Workers are not supported in this browser. '
            'Background execution while the page is closed is unavailable; '
            'tasks still run while the page is open.',
        source: 'page',
      );
    }

    if (useWebWorker) {
      _initializeWebWorker(resolvedDispatcherUrl);
    }

    // In-page fallback path: when no Web Worker is available the dispatcher
    // runs inside the page itself, so its `sendToPage` calls must surface on
    // the page's [workerMessages] stream instead of posting to a worker.
    WorkmanagerExecution.instance.sendToPage = (Object? payload) {
      if (!_workerMessages.isClosed) {
        _workerMessages.add(payload);
      }
    };

    await _syncTasksToServiceWorker();
  }

  /// Registers the background task handler (mirrors
  /// `Workmanager().executeTask(...)`).
  ///
  /// [onTaskStopped] is accepted for API parity with the native plugin but has
  /// no effect on web.
  void executeTask(
    BackgroundTaskHandler backgroundTaskHandler, {
    BackgroundTaskStoppedHandler? onTaskStopped,
  }) {
    WorkmanagerExecution.instance.executeTask(backgroundTaskHandler);
  }

  @override
  Future<void> registerOneOffTask(
    String uniqueName,
    String taskName, {
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    OutOfQuotaPolicy? outOfQuotaPolicy,
    ForegroundServiceConfig? foregroundServiceConfig,
    bool expedited = false,
  }) async {
    _checkInitialized();
    final runAt = DateTime.now().add(initialDelay ?? Duration.zero);
    _tasks[uniqueName] = _RegisteredTask(
      uniqueName: uniqueName,
      taskName: taskName,
      type: _TaskType.oneOff,
      inputData: inputData,
      runAt: runAt,
      tag: tag,
    );
    await _syncTasksToServiceWorker();

    final delay = initialDelay ?? Duration.zero;
    if (delay <= Duration.zero) {
      unawaited(
          _runTask(taskName, inputData, 'trigger', uniqueName: uniqueName));
    } else {
      _oneOffTimers[uniqueName]?.cancel();
      _oneOffTimers[uniqueName] = Timer(delay, () {
        // The Service Worker may already have relayed (and removed) the task;
        // do not run it twice.
        if (_tasks.containsKey(uniqueName)) {
          unawaited(
            _runTask(taskName, inputData, 'timer', uniqueName: uniqueName),
          );
        }
      });
    }
  }

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Duration? flexInterval,
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    ForegroundServiceConfig? foregroundServiceConfig,
  }) async {
    _checkInitialized();
    final frequencyMs =
        (frequency ?? const Duration(minutes: 15)).inMilliseconds;
    _tasks[uniqueName] = _RegisteredTask(
      uniqueName: uniqueName,
      taskName: taskName,
      type: _TaskType.periodic,
      inputData: inputData,
      frequencyMs: frequencyMs,
      tag: tag,
    );
    await _syncTasksToServiceWorker();
    await _registerPeriodicSync(uniqueName, frequencyMs);
  }

  @override
  Future<void> registerProcessingTask(
    String uniqueName,
    String taskName, {
    Duration? initialDelay,
    Map<String, dynamic>? inputData,
    Constraints? constraints,
  }) async {
    throw UnsupportedError('Processing tasks are not supported on web.');
  }

  @override
  Future<void> registerHealthResearchTask(
    String uniqueName,
    String taskName, {
    Duration? initialDelay,
    Map<String, dynamic>? inputData,
    Constraints? constraints,
  }) async {
    throw UnsupportedError('Health research tasks are not supported on web.');
  }

  @override
  Future<void> registerContinuedProcessingTask(
    String uniqueName,
    String taskName, {
    String? title,
    String? subtitle,
    Map<String, dynamic>? inputData,
  }) async {
    throw UnsupportedError(
      'Continued processing tasks are not supported on web.',
    );
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    _checkInitialized();
    _removeTaskLocally(uniqueName);
    await _syncTasksToServiceWorker();
  }

  @override
  Future<void> cancelByTag(String tag) async {
    _checkInitialized();
    final names = _tasks.values
        .where((task) => task.tag == tag)
        .map((task) => task.uniqueName)
        .toList();
    for (final name in names) {
      _removeTaskLocally(name);
    }
    await _syncTasksToServiceWorker();
  }

  @override
  Future<void> cancelAll() async {
    _checkInitialized();
    for (final timer in _oneOffTimers.values) {
      timer.cancel();
    }
    _oneOffTimers.clear();
    _tasks.clear();
    if (_swAvailable) {
      await BrowserGlue.postToActiveServiceWorker(
        <String, Object?>{'type': 'workmanager:cancelAll'},
      );
    }
  }

  @override
  Future<bool> isScheduledByUniqueName(String uniqueName) async {
    _checkInitialized();
    return _tasks.containsKey(uniqueName);
  }

  @override
  Future<String> printScheduledTasks() async {
    _checkInitialized();
    return jsonEncode(_tasks.values.map((task) => task.toJson()).toList());
  }

  @override
  Future<WorkInfo?> getWorkInfo(String uniqueName) async {
    // Browsers have no queryable task state: the Service Worker runs the
    // compiled dispatcher without the plugin's Dart code, so nothing is
    // recorded. Returning null is the documented no-op.
    return null;
  }

  /// Runs [taskName] immediately through the normal execution path (Web
  /// Worker when available, otherwise in-page).
  ///
  /// Useful for demos and tests: it proves the registered handler works
  /// without waiting for the browser scheduler.
  Future<void> triggerTask(
    String taskName, {
    Map<String, dynamic>? inputData,
  }) async {
    _checkInitialized();
    await _runTask(taskName, inputData, 'trigger');
  }

  /// Sends a free-form message to the background worker's dispatcher.
  ///
  /// The message is delivered to the handler registered with
  /// `WorkmanagerExecution.instance.messageHandler` in the compiled dispatcher
  /// bundle. When no Web Worker is available the message is delivered
  /// directly to the in-page dispatcher instead. The call never throws for
  /// missing handlers — it is fire-and-forget, like `postMessage`.
  void sendMessageToWorker(Object? payload) {
    _checkInitialized();
    if (_worker != null && !_workerFailed) {
      BrowserGlue.workerPostMessage(
        _worker,
        WorkerProtocol.encodeMessage(payload),
      );
      return;
    }
    WorkmanagerExecution.instance.messageHandler?.call(payload);
  }

  Future<void> _initializeServiceWorker(
    String serviceWorkerUrl,
    String dispatcherUrl,
  ) async {
    try {
      final registration = await BrowserGlue.registerServiceWorker(
        serviceWorkerUrl,
        dispatcherUrl: dispatcherUrl,
      );
      if (registration == null) {
        throw StateError('navigator.serviceWorker.register() returned null.');
      }
      _swAvailable = true;
      BrowserGlue.listenForServiceWorkerMessages(_handleServiceWorkerMessage);
      await BrowserGlue.postToActiveServiceWorker(
        <String, Object?>{'type': 'workmanager:hello'},
      );
      _emit(
        'info',
        'Service Worker registered at $serviceWorkerUrl '
            '(dispatcher bundle: $dispatcherUrl).',
        source: 'page',
      );
    } catch (e) {
      _emit(
        'warning',
        'Service Worker registration failed: $e. '
            'Tasks will only run while the page is open.',
        source: 'page',
      );
    }
  }

  void _initializeWebWorker(String dispatcherUrl) {
    try {
      _worker = BrowserGlue.createWorker(dispatcherUrl);
      if (_worker == null) {
        _workerFailed = true;
        _emit(
          'warning',
          'Web Workers are not supported here; '
              'falling back to in-page execution.',
          source: 'page',
        );
        return;
      }
      BrowserGlue.workerListen(_worker, _handleWorkerMessage);
      BrowserGlue.workerListenForErrors(_worker, (Object? error) {
        _workerFailed = true;
        _emit(
          'warning',
          'Web Worker failed ($error); '
              'falling back to in-page execution.',
          source: 'page',
        );
      });
      _emit(
        'info',
        'Web Worker started from $dispatcherUrl.',
        source: 'page',
      );
    } catch (e) {
      _workerFailed = true;
      _emit(
        'warning',
        'Could not start the Web Worker: $e; '
            'falling back to in-page execution.',
        source: 'page',
      );
    }
  }

  Future<void> _registerPeriodicSync(
    String uniqueName,
    int frequencyMs,
  ) async {
    if (!_swAvailable) {
      return;
    }
    try {
      await BrowserGlue.registerPeriodicSync(uniqueName, frequencyMs);
      _emit(
        'info',
        'Periodic Background Sync registered for "$uniqueName" '
            '(minInterval ${frequencyMs}ms).',
        source: 'page',
        uniqueName: uniqueName,
      );
    } catch (e) {
      if (frequencyMs >= minimumPeriodicSyncInterval.inMilliseconds) {
        _emit(
          'warning',
          'Periodic Background Sync registration failed for '
              '"$uniqueName": $e',
          source: 'page',
          uniqueName: uniqueName,
        );
        return;
      }
      // Chrome rejects intervals below 12h; clamp and retry.
      try {
        await BrowserGlue.registerPeriodicSync(
          uniqueName,
          minimumPeriodicSyncInterval.inMilliseconds,
        );
        _emit(
          'info',
          'Periodic Background Sync registered for "$uniqueName" with the '
              'browser minimum interval (12h); the requested ${frequencyMs}ms is '
              'below Chrome\'s minimum.',
          source: 'page',
          uniqueName: uniqueName,
        );
      } catch (e2) {
        _emit(
          'warning',
          'Periodic Background Sync registration failed for '
              '"$uniqueName": $e2. Install the PWA, keep engaging with it and '
              're-register the task.',
          source: 'page',
          uniqueName: uniqueName,
        );
      }
    }
  }

  Future<void> _runTask(
    String taskName,
    Object? rawInputData,
    String source, {
    String? uniqueName,
  }) async {
    // A one-off task runs at most once: cancel the in-page timer and remove
    // the local registration before executing so a simultaneous Service
    // Worker relay cannot double-run it.
    final _RegisteredTask? task =
        uniqueName == null ? null : _tasks[uniqueName];
    if (task?.type == _TaskType.oneOff) {
      _oneOffTimers.remove(uniqueName)?.cancel();
      _tasks.remove(uniqueName);
    }
    final started = DateTime.now();
    final taskInfo = TaskDebugInfo(
      taskName: taskName,
      uniqueName: uniqueName,
      inputData: rawInputData is Map
          ? Map<String, dynamic>.from(rawInputData)
          : null,
      startTime: started,
    );
    WorkmanagerDebug.reportStatus(taskInfo, TaskStatus.started, null);
    Object? result;
    String executedIn;
    String? errorMessage;
    try {
      if (_worker != null && !_workerFailed) {
        result = await _runInWorker(taskName, rawInputData);
        executedIn = 'webworker';
      } else {
        _ensureInPageDispatcher();
        result = await WorkmanagerExecution.instance.runTask(
          taskName,
          rawInputData,
        );
        executedIn = 'inpage';
      }
    } catch (e) {
      errorMessage = e.toString();
      executedIn = _workerFailed ? 'inpage' : 'page';
      _emit(
        'error',
        'Task "$taskName" failed: $errorMessage',
        source: source,
        uniqueName: uniqueName,
        taskName: taskName,
      );
    }
    if (errorMessage == null) {
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      WorkmanagerDebug.reportStatus(
        taskInfo,
        TaskStatus.completed,
        TaskResult(
          success: true,
          duration: Duration(milliseconds: elapsed),
        ),
      );
      _emit(
        'executed',
        'Task "$taskName" executed in ${elapsed}ms via $executedIn.',
        source: source,
        uniqueName: uniqueName,
        taskName: taskName,
        result: result,
      );
    } else {
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      WorkmanagerDebug.reportStatus(
        taskInfo,
        TaskStatus.failed,
        TaskResult(
          success: false,
          duration: Duration(milliseconds: elapsed),
          error: errorMessage,
        ),
      );
      WorkmanagerDebug.reportException(
        taskInfo,
        Exception(errorMessage),
        null,
      );
    }
    await _notifyServiceWorkerExecuted(
      uniqueName,
      taskName,
      source,
      result,
      errorMessage,
      task?.type == _TaskType.oneOff,
    );
  }

  Future<Object?> _runInWorker(String taskName, Object? rawInputData) async {
    final requestId = _nextRequestId++;
    final completer = Completer<Object?>();
    _pendingWorkerRequests[requestId] = completer;
    BrowserGlue.workerPostMessage(
      _worker,
      WorkerProtocol.encodeExecuteTask(
        requestId: requestId,
        taskName: taskName,
        inputData: rawInputData,
      ),
    );
    return completer.future.timeout(const Duration(seconds: 30), onTimeout: () {
      _pendingWorkerRequests.remove(requestId);
      _workerFailed = true;
      throw TimeoutException(
        'The Web Worker did not respond within 30s; '
        'falling back to in-page execution.',
      );
    });
  }

  void _handleWorkerMessage(Object? raw) {
    if (raw is! Map) {
      return;
    }
    final map = raw.cast<Object?, Object?>();
    final message = WorkerProtocol.decodeWorkerMessage(map);
    if (message != null || map['type'] == WorkerProtocol.typeWorkerMessage) {
      if (!_workerMessages.isClosed) {
        _workerMessages.add(message);
      }
      return;
    }
    final result = WorkerProtocol.decodeResult(map);
    if (result == null) {
      return;
    }
    final completer = _pendingWorkerRequests.remove(result.requestId);
    if (completer == null) {
      return;
    }
    final error = result.error;
    if (error != null) {
      completer.completeError(
        StateError('Web Worker execution failed: $error'),
      );
    } else {
      completer.complete(result.result);
    }
  }

  void _ensureInPageDispatcher() {
    if (_inPageDispatcherStarted) {
      return;
    }
    _inPageDispatcherStarted = true;
    final dispatcher = WorkmanagerExecution.instance.callbackDispatcher;
    if (dispatcher != null) {
      dispatcher();
    }
  }

  void _handleServiceWorkerMessage(Object? raw) {
    if (raw is! Map) {
      return;
    }
    final map = raw.cast<Object?, Object?>();
    switch (map['type']) {
      case 'workmanager:execute':
        final taskName = map['taskName'];
        if (taskName is String) {
          unawaited(
            _runTask(
              taskName,
              map['inputData'],
              (map['source'] as String?) ?? 'serviceworker',
              uniqueName: map['uniqueName'] as String?,
            ),
          );
        }
      case 'workmanager:hello':
        final events = map['events'];
        if (events is List) {
          for (final event in events) {
            if (event is Map) {
              _emitEventFromMap(event.cast<Object?, Object?>());
            }
          }
        }
      case 'workmanager:event':
        final event = map['event'];
        if (event is Map) {
          _emitEventFromMap(event.cast<Object?, Object?>());
        }
      case 'workerMessage':
        // Free-form message pushed by the dispatcher bundle while running in
        // the Service Worker global (delivered via clients.postMessage).
        final payload = map['payload'];
        if (!_workerMessages.isClosed) {
          _workerMessages.add(payload);
        }
    }
  }

  Future<void> _notifyServiceWorkerExecuted(
    String? uniqueName,
    String taskName,
    String source,
    Object? result,
    String? error,
    bool removeTask,
  ) async {
    if (!_swAvailable || uniqueName == null) {
      return;
    }
    await BrowserGlue.postToActiveServiceWorker(<String, Object?>{
      'type': 'workmanager:taskExecuted',
      'uniqueName': uniqueName,
      'taskName': taskName,
      'source': source,
      'result': result,
      'error': error,
      'removeTask': removeTask,
    });
  }

  Future<void> _syncTasksToServiceWorker() async {
    if (!_swAvailable) {
      return;
    }
    await BrowserGlue.postToActiveServiceWorker(<String, Object?>{
      'type': 'workmanager:setTasks',
      'tasks': _tasks.values.map((task) => task.toJson()).toList(),
    });
  }

  void _removeTaskLocally(String uniqueName) {
    _oneOffTimers.remove(uniqueName)?.cancel();
    _tasks.remove(uniqueName);
  }

  void _emitEventFromMap(Map<Object?, Object?> json) {
    final event = WorkmanagerWebEvent.fromJson(json);
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  void _emit(
    String state,
    String message, {
    String source = 'page',
    String? uniqueName,
    String? taskName,
    Object? result,
  }) {
    if (!_events.isClosed) {
      _events.add(
        WorkmanagerWebEvent(
          timestamp: DateTime.now(),
          state: state,
          source: source,
          uniqueName: uniqueName,
          taskName: taskName,
          result: result,
          message: message,
        ),
      );
    }
  }

  void _checkInitialized() {
    if (!_initialized) {
      throw StateError(
        'WorkmanagerWeb.initialize() must be called before registering tasks.',
      );
    }
  }
}

enum _TaskType { oneOff, periodic }

class _RegisteredTask {
  _RegisteredTask({
    required this.uniqueName,
    required this.taskName,
    required this.type,
    this.inputData,
    this.runAt,
    this.frequencyMs,
    this.tag,
  });

  final String uniqueName;
  final String taskName;
  final _TaskType type;
  final Map<String, dynamic>? inputData;
  final DateTime? runAt;
  final int? frequencyMs;
  final String? tag;

  Map<String, Object?> toJson() => <String, Object?>{
        'uniqueName': uniqueName,
        'taskName': taskName,
        'type': type.name,
        'inputData': inputData,
        'runAt': runAt?.millisecondsSinceEpoch,
        'frequencyMs': frequencyMs,
        'tag': tag,
      };
}
