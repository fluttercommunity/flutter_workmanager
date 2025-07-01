import 'package:pigeon/pigeon.dart';

// Pigeon configuration
@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/pigeon/workmanager_api.g.dart',
  dartOptions: DartOptions(),
  kotlinOut: 'android/src/main/kotlin/dev/fluttercommunity/workmanager/pigeon/WorkmanagerApi.g.kt',
  kotlinOptions: KotlinOptions(
    package: 'dev.fluttercommunity.workmanager.pigeon',
  ),
  swiftOut: 'ios/Classes/pigeon/WorkmanagerApi.g.swift',
  copyrightHeader: 'pigeons/copyright.txt',
  dartPackageName: 'workmanager_platform_interface',
))

// Enums - Moved from platform interface for Pigeon compatibility

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

/// An enumeration of the conflict resolution policies in case of a collision.
enum ExistingWorkPolicy {
  /// If there is existing pending (uncompleted) work with the same unique name, append the newly-specified work as a child of all the leaves of that work sequence.
  append,

  /// If there is existing pending (uncompleted) work with the same unique name, do nothing.
  keep,

  /// If there is existing pending (uncompleted) work with the same unique name, cancel and delete it.
  replace,

  /// If there is existing pending (uncompleted) work with the same unique name, it will be updated the new specification.
  /// Note: This maps to appendOrReplace in the native implementation.
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
  InitializeRequest({required this.callbackHandle, required this.isInDebugMode});
  
  int callbackHandle;
  bool isInDebugMode;
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
  ExistingWorkPolicy? existingWorkPolicy;
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