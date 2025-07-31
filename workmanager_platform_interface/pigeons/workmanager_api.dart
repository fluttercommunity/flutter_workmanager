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
  swiftOut: '../workmanager_apple/ios/Classes/pigeon/WorkmanagerApi.g.swift',
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

// Data classes
class Constraints {
  Constraints({
    this.networkType,
    this.requiresBatteryNotLow,
    this.requiresCharging,
    this.requiresDeviceIdle,
    this.requiresStorageNotLow,
  });

  NetworkType? networkType;
  bool? requiresBatteryNotLow;
  bool? requiresCharging;
  bool? requiresDeviceIdle;
  bool? requiresStorageNotLow;
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
  void cancelByUniqueName(String uniqueName);

  @async
  void cancelByTag(String tag);

  @async
  void cancelAll();

  @async
  bool isScheduledByUniqueName(String uniqueName);

  @async
  String printScheduledTasks();
}

// Flutter API (Native calls Flutter)
@FlutterApi()
abstract class WorkmanagerFlutterApi {
  @async
  void backgroundChannelInitialized();

  @async
  bool executeTask(String taskName, Map<String?, Object?>? inputData);
}
