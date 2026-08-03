import 'dart:ui';
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

/// Apple (iOS/macOS) implementation of [WorkmanagerPlatform].
class WorkmanagerApple extends WorkmanagerPlatform {
  /// The Pigeon API instance for type-safe communication.
  final WorkmanagerHostApi _api = WorkmanagerHostApi();

  /// Constructs a WorkmanagerApple instance.
  WorkmanagerApple() : super();

  /// Registers this class as the default instance of [WorkmanagerPlatform].
  static void registerWith() {
    WorkmanagerPlatform.instance = WorkmanagerApple();
  }

  @override
  Future<void> initialize(
    Function callbackDispatcher, {
    @Deprecated(
        'Use WorkmanagerDebug handlers instead. This parameter has no effect.')
    bool isInDebugMode = false,
  }) async {
    final callback = PluginUtilities.getCallbackHandle(callbackDispatcher);
    await _api.initialize(InitializeRequest(
      callbackHandle: callback!.toRawHandle(),
    ));
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
    // Foreground service config and expedited are Android-only; they are
    // intentionally ignored.
    await _api.registerOneOffTask(OneOffTaskRequest(
      uniqueName: uniqueName,
      taskName: taskName,
      inputData: inputData?.cast<String?, Object?>(),
      initialDelaySeconds: initialDelay?.inSeconds,
      constraints: constraints,
      existingWorkPolicy: existingWorkPolicy,
      backoffPolicy: backoffPolicyDelay != null && backoffPolicy != null
          ? BackoffPolicyConfig(
              backoffPolicy: backoffPolicy,
              backoffDelayMillis: backoffPolicyDelay.inMilliseconds,
            )
          : null,
      tag: tag,
      outOfQuotaPolicy: outOfQuotaPolicy,
    ));
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
    // Foreground service config is Android-only; it is intentionally ignored.
    await _api.registerPeriodicTask(PeriodicTaskRequest(
      uniqueName: uniqueName,
      taskName: taskName,
      frequencySeconds: frequency?.inSeconds ?? 900, // Default 15 minutes
      flexIntervalSeconds: flexInterval?.inSeconds,
      inputData: inputData?.cast<String?, Object?>(),
      initialDelaySeconds: initialDelay?.inSeconds,
      constraints: constraints,
      existingWorkPolicy: existingWorkPolicy,
      backoffPolicy: backoffPolicyDelay != null && backoffPolicy != null
          ? BackoffPolicyConfig(
              backoffPolicy: backoffPolicy,
              backoffDelayMillis: backoffPolicyDelay.inMilliseconds,
            )
          : null,
      tag: tag,
    ));
  }

  @override
  Future<void> registerProcessingTask(
    String uniqueName,
    String taskName, {
    Duration? initialDelay,
    Map<String, dynamic>? inputData,
    Constraints? constraints,
  }) async {
    await _api.registerProcessingTask(ProcessingTaskRequest(
      uniqueName: uniqueName,
      taskName: taskName,
      inputData: inputData?.cast<String?, Object?>(),
      initialDelaySeconds: initialDelay?.inSeconds,
      networkType: constraints?.networkType,
      requiresCharging: constraints?.requiresCharging,
    ));
  }

  @override
  Future<void> beginUniqueWork(
    String uniqueName, {
    required List<WorkChainTask> tasks,
    ExistingWorkPolicy? existingWorkPolicy,
  }) async {
    // Work chaining maps to WorkManager's beginUniqueWork/then/enqueue,
    // which does not exist on iOS/macOS. Re-submitting the next link from
    // inside the callback (see docs/customization.mdx) is the Apple
    // equivalent.
    throw UnsupportedError('Work chaining is not supported on iOS/macOS');
  }

  @override
  Future<void> registerHealthResearchTask(
    String uniqueName,
    String taskName, {
    Duration? initialDelay,
    Map<String, dynamic>? inputData,
    Constraints? constraints,
  }) async {
    await _api.registerHealthResearchTask(HealthResearchTaskRequest(
      uniqueName: uniqueName,
      taskName: taskName,
      inputData: inputData?.cast<String?, Object?>(),
      initialDelaySeconds: initialDelay?.inSeconds,
      networkType: constraints?.networkType,
      requiresCharging: constraints?.requiresCharging,
    ));
  }

  @override
  Future<void> registerContinuedProcessingTask(
    String uniqueName,
    String taskName, {
    String? title,
    String? subtitle,
    Map<String, dynamic>? inputData,
  }) async {
    await _api.registerContinuedProcessingTask(ContinuedProcessingTaskRequest(
      uniqueName: uniqueName,
      taskName: taskName,
      title: title,
      subtitle: subtitle,
      inputData: inputData?.cast<String?, Object?>(),
    ));
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    await _api.cancelByUniqueName(uniqueName);
  }

  @override
  Future<void> cancelByTag(String tag) async {
    // Tags are not directly supported on iOS, so this is a no-op
    throw UnsupportedError('cancelByTag is not supported on iOS');
  }

  @override
  Future<void> cancelAll() async {
    await _api.cancelAll();
  }

  @override
  Future<bool> isScheduledByUniqueName(String uniqueName) async {
    // isScheduledByUniqueName is Android-only functionality
    throw UnsupportedError('isScheduledByUniqueName is not supported on iOS');
  }

  @override
  Future<String> printScheduledTasks() async {
    return await _api.printScheduledTasks();
  }

  @override
  Future<WorkInfo?> getWorkInfo(String uniqueName) async {
    final data = await _api.getWorkInfoByUniqueName(uniqueName);
    return data == null ? null : WorkInfo.fromData(data);
  }
}
