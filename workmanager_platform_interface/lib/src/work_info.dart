import 'package:flutter/foundation.dart';

import 'pigeon/workmanager_api.g.dart' show WorkInfoData, WorkState;

export 'pigeon/workmanager_api.g.dart' show WorkState;

/// A snapshot of the current state of a background task, as observed by the
/// plugin.
///
/// `WorkInfo` is the platform-agnostic answer to "what is my task doing right
/// now?". The fields are populated from the most truthful source each platform
/// has:
///
/// * **Android** — the query is served by WorkManager itself
///   (`getWorkInfosForUniqueWork`), so [state] is authoritative. WorkManager
///   does not expose a finish timestamp, so [lastFinishedAt] is always `null`
///   on Android.
/// * **iOS / macOS** — BGTaskScheduler has **no query API**, so the plugin
///   persists its own per-task state (in `UserDefaults`) as it observes its
///   own task-status pipeline. The result is best-effort: it reflects what
///   the plugin has seen since the task was registered (see the docs).
/// * **Web** — returns `null` (no queryable state).
/// * **Other platforms** — `getWorkInfo` throws
///   [UnsupportedError], like every other platform API.
///
/// See the "Work status" docs page for the full per-platform truthfulness
/// matrix.
@immutable
class WorkInfo {
  /// Creates a [WorkInfo] snapshot.
  const WorkInfo({
    required this.uniqueName,
    required this.state,
    required this.isPeriodic,
    this.taskName,
    this.tags = const <String>[],
    this.lastFinishedAt,
  });

  /// Converts the native transport snapshot into the public model.
  factory WorkInfo.fromData(WorkInfoData data) {
    return WorkInfo(
      uniqueName: data.uniqueName,
      state: data.state,
      isPeriodic: data.isPeriodic,
      taskName: data.taskName,
      tags: (data.tags ?? const <String?>[]).whereType<String>().toList(),
      lastFinishedAt: data.lastFinishedAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(data.lastFinishedAtMillis!),
    );
  }

  /// The unique name the task was registered with.
  final String uniqueName;

  /// The task's current state.
  ///
  /// On Apple platforms this is the plugin's best-effort view persisted from
  /// its own status pipeline; on Android it is WorkManager's authoritative
  /// state.
  final WorkState state;

  /// Whether the task was registered via `registerPeriodicTask`.
  ///
  /// On Android this reflects WorkManager's own periodicity information; on
  /// Apple platforms it is what the plugin recorded at registration time.
  final bool isPeriodic;

  /// The task name the work was registered with, when the platform exposes it.
  ///
  /// On Android this is read from the worker's input data; on Apple platforms
  /// it is what the plugin recorded at registration time.
  final String? taskName;

  /// Tags the work was registered with.
  ///
  /// Android only (WorkManager tags); always empty on Apple platforms, which
  /// have no tag concept.
  final List<String> tags;

  /// When the plugin last observed the task finish (succeeded, failed or was
  /// cancelled).
  ///
  /// Always `null` on Android: WorkManager does not expose a finish timestamp.
  /// On Apple platforms it is recorded from the plugin's persisted state and
  /// is best-effort (it is only set for tasks the plugin saw finish while it
  /// was running).
  final DateTime? lastFinishedAt;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is WorkInfo &&
        other.uniqueName == uniqueName &&
        other.state == state &&
        other.isPeriodic == isPeriodic &&
        other.taskName == taskName &&
        listEquals(other.tags, tags) &&
        other.lastFinishedAt == lastFinishedAt;
  }

  @override
  int get hashCode => Object.hash(uniqueName, state, isPeriodic, taskName,
      Object.hashAll(tags), lastFinishedAt);

  @override
  String toString() {
    return 'WorkInfo(uniqueName: $uniqueName, state: $state, '
        'isPeriodic: $isPeriodic, taskName: $taskName, tags: $tags, '
        'lastFinishedAt: $lastFinishedAt)';
  }
}
