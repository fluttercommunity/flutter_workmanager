import 'package:pigeon/pigeon.dart';

// Pigeon configuration
@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/pigeon/workmanager_api.g.dart',
  dartOptions: DartOptions(),
  kotlinOut:
      '../workmanager_android/android/src/main/kotlin/dev/fluttercommunity/workmanager/pigeon/WorkmanagerApi.g.kt',
  kotlinOptions: KotlinOptions(
    package: 'dev.fluttercommunity.workmanager.pigeon',
  ),
  swiftOut:
      '../workmanager_apple/ios/workmanager_apple/Sources/workmanager_apple/pigeon/WorkmanagerApi.g.swift',
  copyrightHeader: 'pigeons/copyright.txt',
  dartPackageName: 'workmanager_platform_interface',
))

// Enums - Moved from platform interface for Pigeon compatibility

/// Task status for debugging and monitoring.
enum TaskStatus {
  /// Task has been scheduled
  scheduled,

  /// Task has started execution
  started,

  /// Task completed successfully
  completed,

  /// Task failed
  failed,

  /// Task was cancelled
  cancelled,

  /// Task is being retried
  retrying,

  /// Task was rescheduled for later execution
  rescheduled,
}

/// An enumeration of various network types that can be used as Constraints for work.
///
/// Fully supported on Android.
///
/// On iOS, this enumeration is used to define whether a piece of work requires
/// internet connectivity, by checking for either [NetworkType.connected] or
/// [NetworkType.metered].
enum NetworkType {
  /// Any working network connection is required for this work.
  connected,

  /// A metered network connection is required for this work.
  metered,

  /// Default value. A network is not required for this work.
  notRequired,

  /// A non-roaming network connection is required for this work.
  notRoaming,

  /// An unmetered network connection is required for this work.
  unmetered,

  /// A temporarily unmetered Network. This capability will be set for
  /// networks that are generally metered, but are currently unmetered.
  ///
  /// Android API 30+
  temporarilyUnmetered,
}

/// An enumeration of backoff policies when retrying work.
/// These policies are used when you have a return ListenableWorker.Result.retry() from a worker to determine the correct backoff time.
/// Backoff policies are set in WorkRequest.Builder.setBackoffCriteria(BackoffPolicy, long, TimeUnit) or one of its variants.
enum BackoffPolicy {
  /// Used to indicate that WorkManager should increase the backoff time exponentially
  exponential,

  /// Used to indicate that WorkManager should increase the backoff time linearly
  linear,
}

/// An enumeration of the conflict resolution policies when registering one-off work with the same unique name.
///
/// This policy determines what happens when you register a one-off task with a unique name that already exists.
///
/// See: https://developer.android.com/reference/androidx/work/ExistingWorkPolicy
enum ExistingWorkPolicy {
  /// If there is existing pending (uncompleted) work with the same unique name, append the newly-specified work as a child of all the leaves of that work sequence.
  append,

  /// If there is existing pending (uncompleted) work with the same unique name, do nothing.
  /// The new work request is ignored and the existing work continues unchanged.
  keep,

  /// If there is existing pending (uncompleted) work with the same unique name, cancel and delete it.
  /// The new work request replaces the existing one entirely.
  replace,

  /// If there is existing pending (uncompleted) work with the same unique name, it will be updated with the new specification.
  /// Note: This maps to appendOrReplace in the native implementation.
  update,
}

/// An enumeration of the conflict resolution policies when registering periodic work with the same unique name.
///
/// This policy determines what happens when you register a periodic task with a unique name that already exists.
/// This is especially important during development when you might register the same task multiple times
/// with different frequencies or configurations.
///
/// See: https://developer.android.com/reference/androidx/work/ExistingPeriodicWorkPolicy
enum ExistingPeriodicWorkPolicy {
  /// If there is existing pending (uncompleted) work with the same unique name, do nothing.
  /// The new work request is ignored and the existing work continues unchanged.
  ///
  /// **Warning**: If you previously registered a periodic task with a short frequency
  /// (e.g., 15 minutes) and later register the same task with a longer frequency (e.g., 2 hours),
  /// the task will continue running at the original short frequency. This can cause confusion
  /// during development. Consider using [update] instead.
  keep,

  /// If there is existing pending (uncompleted) work with the same unique name, cancel and delete it.
  /// The new work request replaces the existing one entirely.
  ///
  /// **Deprecated**: Android recommends using [update] instead for less disruptive updates.
  replace,

  /// If there is existing pending (uncompleted) work with the same unique name, it will be updated with the new specification.
  ///
  /// **Recommended** - updates existing work without canceling running workers and preserves original timing.
  /// This is the default policy for periodic tasks to prevent frequency confusion.
  ///
  /// Available since WorkManager 2.8.0.
  update,
}

/// An enumeration of policies that help determine out of quota behavior for expedited jobs.
///
/// Only supported on Android.
enum OutOfQuotaPolicy {
  /// When the app does not have any expedited job quota, the expedited work request will
  /// fallback to a regular work request.
  runAsNonExpeditedWorkRequest,

  /// When the app does not have any expedited job quota, the expedited work request will
  /// we dropped and no work requests are enqueued.
  dropWorkRequest,
}

/// The lifecycle state of a background task as observed by the plugin.
///
/// This is the cross-platform subset of Android WorkManager's
/// `WorkInfo.State` (ENQUEUED/RUNNING/SUCCEEDED/FAILED/CANCELLED/BLOCKED).
/// On Apple platforms it reflects what the plugin itself has persisted from
/// its task-status pipeline, because BGTaskScheduler has no query API.
enum WorkState {
  /// The task is registered and waiting to run (Android ENQUEUED/BLOCKED).
  scheduled,

  /// The task is currently executing.
  running,

  /// The task finished successfully.
  succeeded,

  /// The task failed permanently.
  failed,

  /// The task was cancelled before finishing.
  cancelled,
}

/// Foreground service types supported for Android long-running workers.
///
/// These map to the foreground service types introduced by Android 14
/// (API level 34), when specifying a type became mandatory for apps targeting
/// SDK 34+. See:
/// https://developer.android.com/about/versions/14/changes/fgs-types-required
enum ForegroundServiceType {
  /// Used for long-running data synchronization, uploads and downloads that
  /// are important to the user.
  dataSync,

  /// Used for short, critical work that the user is aware of and that must
  /// complete quickly (a few minutes at most).
  shortService,
}

/// Android-only configuration that promotes a worker to a foreground service
/// while it runs, keeping the process alive for long-running work.
///
/// When provided to [OneOffTaskRequest.foregroundServiceConfig] or
/// [PeriodicTaskRequest.foregroundServiceConfig], the worker calls
/// WorkManager's `setForegroundAsync` as soon as it starts and shows a
/// notification for the whole duration of the task.
///
/// All fields are optional; the platform implementation fills in sane
/// defaults for anything that is not provided.
class ForegroundServiceConfig {
  ForegroundServiceConfig({
    this.notificationTitle,
    this.notificationText,
    this.notificationChannelId,
    this.notificationChannelName,
    this.notificationId,
    this.foregroundServiceType,
  });

  /// Title shown in the foreground service notification.
  String? notificationTitle;

  /// Body text shown in the foreground service notification.
  String? notificationText;

  /// Id of the notification channel used for the foreground service
  /// notification (Android 8.0+).
  String? notificationChannelId;

  /// User-visible name of the notification channel.
  String? notificationChannelName;

  /// Id used for the foreground service notification.
  int? notificationId;

  /// Foreground service type to start with (Android 14+). Defaults to
  /// [ForegroundServiceType.dataSync].
  ForegroundServiceType? foregroundServiceType;
}

// Data classes
class Constraints {
  Constraints({
    this.networkType,
    this.requiresBatteryNotLow,
    this.requiresCharging,
    this.requiresDeviceIdle,
    this.requiresStorageNotLow,
    this.contentUriTriggers,
  });

  NetworkType? networkType;
  bool? requiresBatteryNotLow;
  bool? requiresCharging;
  bool? requiresDeviceIdle;
  bool? requiresStorageNotLow;

  /// Content URI triggers that run the work when the observed content URIs
  /// change (Android only).
  ///
  /// Mirrors WorkManager's `Constraints.Builder.addContentUriTrigger`:
  /// https://developer.android.com/reference/androidx/work/Constraints.Builder#addContentUriTrigger(android.net.Uri,%20boolean)
  ///
  /// Requires Android 7.0 (API 24)+; on older Android versions the triggers
  /// are ignored. WorkManager also limits how many content-URI-triggered
  /// workers can be enqueued at once (default 8, configurable via
  /// `Configuration.Builder.setContentUriTriggerWorkersLimit`).
  ///
  /// Other platforms ignore this field.
  List<ContentUriTrigger?>? contentUriTriggers;
}

/// A single content URI trigger for Android WorkManager constraints.
///
/// When [uri] is updated, inserted or deleted by the system or another app,
/// the work associated with the constraint is run.
///
/// Mirrors WorkManager's `ContentUriTrigger`:
/// https://developer.android.com/reference/androidx/work/ContentUriTrigger
class ContentUriTrigger {
  ContentUriTrigger({
    required this.uri,
    required this.triggerForDescendants,
  });

  /// The local `content:` Uri to observe for changes, e.g.
  /// `content://media/external/images/media`.
  String uri;

  /// Whether changes to any descendant of [uri] also run the work.
  bool triggerForDescendants;
}

class BackoffPolicyConfig {
  BackoffPolicyConfig({
    this.backoffPolicy,
    this.backoffDelayMillis,
  });

  BackoffPolicy? backoffPolicy;
  int? backoffDelayMillis;
}

class InitializeRequest {
  InitializeRequest({required this.callbackHandle});

  int callbackHandle;
}

class OneOffTaskRequest {
  OneOffTaskRequest({
    required this.uniqueName,
    required this.taskName,
    this.inputData,
    this.initialDelaySeconds,
    this.constraints,
    this.backoffPolicy,
    this.tag,
    this.existingWorkPolicy,
    this.outOfQuotaPolicy,
    this.foregroundServiceConfig,
    this.expedited,
  });

  String uniqueName;
  String taskName;
  Map<String?, Object?>? inputData;
  int? initialDelaySeconds;
  Constraints? constraints;
  BackoffPolicyConfig? backoffPolicy;
  String? tag;
  ExistingWorkPolicy? existingWorkPolicy;
  OutOfQuotaPolicy? outOfQuotaPolicy;

  /// When set, the worker runs as an Android foreground service.
  ForegroundServiceConfig? foregroundServiceConfig;

  /// When true (Android only), the task is scheduled as expedited work.
  ///
  /// WorkManager runs expedited work with high priority; on Android 12
  /// (API 31)+ the system runs it as a WorkManager-managed foreground
  /// service and shows a notification to the user. Only meaningful for
  /// one-off tasks — periodic tasks cannot be expedited. Other platforms
  /// ignore this field.
  bool? expedited;
}

class PeriodicTaskRequest {
  PeriodicTaskRequest({
    required this.uniqueName,
    required this.taskName,
    required this.frequencySeconds,
    this.flexIntervalSeconds,
    this.inputData,
    this.initialDelaySeconds,
    this.constraints,
    this.backoffPolicy,
    this.tag,
    this.existingWorkPolicy,
    this.foregroundServiceConfig,
  });

  String uniqueName;
  String taskName;
  int frequencySeconds;
  int? flexIntervalSeconds;
  Map<String?, Object?>? inputData;
  int? initialDelaySeconds;
  Constraints? constraints;
  BackoffPolicyConfig? backoffPolicy;
  String? tag;
  ExistingPeriodicWorkPolicy? existingWorkPolicy;

  /// When set, the worker runs as an Android foreground service.
  ForegroundServiceConfig? foregroundServiceConfig;
}

// iOS specific request
class ProcessingTaskRequest {
  ProcessingTaskRequest({
    required this.uniqueName,
    required this.taskName,
    this.inputData,
    this.initialDelaySeconds,
    this.networkType,
    this.requiresCharging,
  });

  String uniqueName;
  String taskName;
  Map<String?, Object?>? inputData;
  int? initialDelaySeconds;
  NetworkType? networkType;
  bool? requiresCharging;
}

// iOS specific request
// BGHealthResearchTaskRequest (iOS 17+) for apps participating in health
// research studies. It extends BGProcessingTaskRequest and is scheduled the
// same way, but is delivered with higher priority/reliability for study-
// essential processing.
class HealthResearchTaskRequest {
  HealthResearchTaskRequest({
    required this.uniqueName,
    required this.taskName,
    this.inputData,
    this.initialDelaySeconds,
    this.networkType,
    this.requiresCharging,
  });

  String uniqueName;
  String taskName;
  Map<String?, Object?>? inputData;
  int? initialDelaySeconds;
  NetworkType? networkType;
  bool? requiresCharging;
}

// iOS specific request
// BGContinuedProcessingTaskRequest (iOS 26+) for workloads that must begin
// immediately or shortly after submission and are allowed to continue running
// while the app is backgrounded (e.g. ML inference on captured camera data).
// The system presents a Live Activity to the user while the task is running.
//
// Unlike processing tasks, the identifier must use wildcard notation ending
// in `.*` (e.g. `<bundleID>.<context>.*`), and the scheduler ignores
// `earliestBeginDate` (so initialDelay does not apply).
class ContinuedProcessingTaskRequest {
  ContinuedProcessingTaskRequest({
    required this.uniqueName,
    required this.taskName,
    this.title,
    this.subtitle,
    this.inputData,
  });

  String uniqueName;
  String taskName;
  String? title;
  String? subtitle;
  Map<String?, Object?>? inputData;
}

/// Snapshot of the current state of a background task, as served by the
/// native platform. This is the transport type for [WorkmanagerHostApi.getWorkInfoByUniqueName];
/// the public, platform-agnostic model is `WorkInfo`.
class WorkInfoData {
  WorkInfoData({
    required this.uniqueName,
    required this.state,
    required this.isPeriodic,
    this.taskName,
    this.tags,
    this.lastFinishedAtMillis,
  });

  /// The unique name the task was registered with.
  String uniqueName;

  /// The task's current state.
  WorkState state;

  /// True when the task was registered as a periodic task.
  bool isPeriodic;

  /// The task name the work was registered with, when the platform exposes it.
  String? taskName;

  /// Tags the work was registered with (Android only; empty elsewhere).
  List<String?>? tags;

  /// When the plugin last observed the task finish (succeeded, failed or was
  /// cancelled), as epoch milliseconds, when the platform exposes it.
  /// Android WorkManager has no finish timestamp, so this is null there.
  int? lastFinishedAtMillis;
}

// Host API (Flutter calls native)
@HostApi()
abstract class WorkmanagerHostApi {
  @async
  void initialize(InitializeRequest request);

  @async
  void registerOneOffTask(OneOffTaskRequest request);

  @async
  void registerPeriodicTask(PeriodicTaskRequest request);

  @async
  void registerProcessingTask(ProcessingTaskRequest request);

  @async
  void registerHealthResearchTask(HealthResearchTaskRequest request);

  @async
  void registerContinuedProcessingTask(ContinuedProcessingTaskRequest request);

  @async
  void cancelByUniqueName(String uniqueName);

  @async
  void cancelByTag(String tag);

  @async
  void cancelAll();

  @async
  bool isScheduledByUniqueName(String uniqueName);

  @async
  String printScheduledTasks();

<<<<<<< HEAD
  /// Returns the current state of the task registered under [uniqueName], or
  /// null when the platform has no record of it.
  @async
  WorkInfoData? getWorkInfoByUniqueName(String uniqueName);
=======
  /// Reports progress for the task that is currently running (Android only).
  ///
  /// Must be called from inside the background task handler; the native side
  /// resolves the running task's unique name from the calling context, so the
  /// [progress] map is the only argument. On platforms without progress
  /// support (iOS/macOS/web/desktop) the call is a no-op.
  @async
  void reportProgress(Map<String?, Object?>? progress);

  /// Enables or disables forwarding of progress updates to the app (Android
  /// only).
  ///
  /// When [enabled] is true the native side starts forwarding progress events
  /// (delivered through [WorkmanagerFlutterApi.onProgressUpdate]) to the
  /// messenger of the engine that made this call. On platforms without
  /// progress support the call is a no-op.
  @async
  void setProgressListener(bool enabled);
>>>>>>> ab45b65 (feat(android): progress updates for long-running tasks)
}

// Flutter API (Native calls Flutter)
@FlutterApi()
abstract class WorkmanagerFlutterApi {
  @async
  void backgroundChannelInitialized();

  @async
  bool executeTask(String taskName, Map<String?, Object?>? inputData);

  /// Notifies the Dart callback that a running task was stopped by the
  /// platform before it finished (cancelled, timed out, preempted, ...).
  ///
  /// [stopReason] carries the Android WorkManager stop reason (see
  /// [StopReason](https://developer.android.com/reference/androidx/work/StopReason)).
  /// It is `0` (unknown) on Android versions before 12 (API 31) and on
  /// platforms without an equivalent concept.
  @async
  void onTaskStopped(String taskName, int stopReason);

  /// Delivers a progress update for a running task to the app (Android only).
  ///
  /// [uniqueName] is the unique name the task was registered with. [progress]
  /// is the progress map the task handler reported via
  /// [WorkmanagerHostApi.reportProgress]. This is only invoked when the app
  /// registered a progress listener (see `Workmanager().setProgressListener`);
  /// on platforms without progress support it is never invoked.
  @async
  void onProgressUpdate(String uniqueName, Map<String?, Object?>? progress);
}
