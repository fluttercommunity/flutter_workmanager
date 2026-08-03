import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'pigeon/workmanager_api.g.dart';
import 'work_info.dart';

/// The interface that implementations of workmanager must implement.
///
/// Platform implementations should extend this class rather than implement it as `workmanager`
/// does not consider newly added methods to be breaking changes. Extending this class
/// (using `extends`) ensures that the subclass will get the default implementation, while
/// platform implementations that `implements` this interface will be broken by newly added
/// [WorkmanagerPlatform] methods.
abstract class WorkmanagerPlatform extends PlatformInterface {
  /// Constructs a WorkmanagerPlatform.
  WorkmanagerPlatform() : super(token: _token);

  static final Object _token = Object();

  static WorkmanagerPlatform _instance = _PlaceholderImplementation();

  /// The default instance of [WorkmanagerPlatform] to use.
  ///
  /// Defaults to [_PlaceholderImplementation].
  static WorkmanagerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [WorkmanagerPlatform] when
  /// they register themselves.
  static set instance(WorkmanagerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initialize the platform workmanager with the callback function.
  ///
  /// [callbackDispatcher] is the callback function that will be called when background work is executed.
  /// [isInDebugMode] is deprecated and has no effect. Use WorkmanagerDebug handlers instead.
  Future<void> initialize(Function callbackDispatcher,
      {@Deprecated(
          'Use WorkmanagerDebug handlers instead. This parameter has no effect.')
      bool isInDebugMode = false}) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Register a one-off task that will be executed once in the background.
  ///
  /// [uniqueName] is the unique identifier for this task.
  /// [taskName] is the name of the task that will be passed to the callback.
  /// [inputData] is optional data that will be passed to the callback.
  /// [initialDelay] is the delay before the task is executed.
  /// [constraints] are the constraints that must be met for the task to run.
  /// [existingWorkPolicy] determines what happens if work with the same uniqueName already exists.
  /// [backoffPolicy] determines the backoff policy for retries.
  /// [backoffPolicyDelay] is the delay for the backoff policy.
  /// [tag] is an optional tag for the task.
  /// [outOfQuotaPolicy] determines behavior when quota is exceeded (Android only).
  /// [expedited] schedules the task as expedited work (Android only, one-off
  /// tasks only; other platforms ignore it).
  /// [foregroundServiceConfig] promotes the worker to an Android foreground
  /// service while it runs (Android only).
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
  }) {
    throw UnimplementedError('registerOneOffTask() has not been implemented.');
  }

  /// Register a periodic task that will be executed repeatedly in the background.
  ///
  /// [uniqueName] is the unique identifier for this task.
  /// [taskName] is the name of the task that will be passed to the callback.
  /// [frequency] is how often the task should repeat.
  /// [flexInterval] is the flex interval for the periodic task (Android only).
  /// [inputData] is optional data that will be passed to the callback.
  /// [initialDelay] is the delay before the first execution.
  /// [constraints] are the constraints that must be met for the task to run.
  /// [existingWorkPolicy] determines what happens if work with the same uniqueName already exists.
  /// [backoffPolicy] determines the backoff policy for retries.
  /// [backoffPolicyDelay] is the delay for the backoff policy.
  /// [tag] is an optional tag for the task.
  /// [foregroundServiceConfig] promotes the worker to an Android foreground
  /// service while it runs (Android only).
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
  }) {
    throw UnimplementedError(
        'registerPeriodicTask() has not been implemented.');
  }

  /// Register a processing task (iOS only).
  ///
  /// [uniqueName] is the unique identifier for this task.
  /// [taskName] is the name of the task that will be passed to the callback.
  /// [initialDelay] is the delay before the task is executed.
  /// [inputData] is optional data that will be passed to the callback.
  /// [constraints] are the constraints that must be met for the task to run.
  Future<void> registerProcessingTask(
    String uniqueName,
    String taskName, {
    Duration? initialDelay,
    Map<String, dynamic>? inputData,
    Constraints? constraints,
  }) {
    throw UnimplementedError(
        'registerProcessingTask() has not been implemented.');
  }

  /// Register a health research task (iOS 17+ only).
  ///
  /// [uniqueName] is the unique identifier for this task.
  /// [taskName] is the name of the task that will be passed to the callback.
  /// [initialDelay] is the delay before the task is executed.
  /// [inputData] is optional data that will be passed to the callback.
  /// [constraints] are the constraints that must be met for the task to run.
  Future<void> registerHealthResearchTask(
    String uniqueName,
    String taskName, {
    Duration? initialDelay,
    Map<String, dynamic>? inputData,
    Constraints? constraints,
  }) {
    throw UnimplementedError(
        'registerHealthResearchTask() has not been implemented.');
  }

  /// Register a continued processing task (iOS 26+ only).
  ///
  /// [uniqueName] is the unique identifier for this task. On iOS the
  /// identifier must use wildcard notation ending in `.*` (e.g.
  /// `<bundleID>.<context>.*`).
  /// [taskName] is the name of the task that will be passed to the callback.
  /// [title] and [subtitle] are the localized strings the system shows to the
  /// user in the Live Activity while the task is running.
  /// [inputData] is optional data that will be passed to the callback.
  Future<void> registerContinuedProcessingTask(
    String uniqueName,
    String taskName, {
    String? title,
    String? subtitle,
    Map<String, dynamic>? inputData,
  }) {
    throw UnimplementedError(
        'registerContinuedProcessingTask() has not been implemented.');
  }

  /// Cancel a task by its unique name.
  Future<void> cancelByUniqueName(String uniqueName) {
    throw UnimplementedError('cancelByUniqueName() has not been implemented.');
  }

  /// Cancel a task by its tag.
  Future<void> cancelByTag(String tag) {
    throw UnimplementedError('cancelByTag() has not been implemented.');
  }

  /// Cancel all registered tasks.
  Future<void> cancelAll() {
    throw UnimplementedError('cancelAll() has not been implemented.');
  }

  /// Check if a task is scheduled by its unique name (Android only).
  Future<bool> isScheduledByUniqueName(String uniqueName) {
    throw UnimplementedError(
        'isScheduledByUniqueName() has not been implemented.');
  }

  /// Print scheduled tasks for debugging (iOS only).
  Future<String> printScheduledTasks() {
    throw UnimplementedError('printScheduledTasks() has not been implemented.');
  }

  /// Queries the current state of the task registered under [uniqueName].
  ///
  /// Returns `null` when the platform has no record of the task. See [WorkInfo]
  /// for the per-platform truthfulness of the result.
  Future<WorkInfo?> getWorkInfo(String uniqueName) {
    throw UnimplementedError('getWorkInfo() has not been implemented.');
  }
}

/// Placeholder implementation that throws on all methods.
class _PlaceholderImplementation extends WorkmanagerPlatform {
  @override
  Future<void> initialize(
    Function callbackDispatcher, {
    @Deprecated(
        'Use WorkmanagerDebug handlers instead. This parameter has no effect.')
    bool isInDebugMode = false,
  }) async {
    throw UnimplementedError(
      'No implementation found for workmanager on this platform. '
      'Make sure to add the platform-specific implementation package to your dependencies.',
    );
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
    throw UnimplementedError(
      'No implementation found for workmanager on this platform.',
    );
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
    throw UnimplementedError(
      'No implementation found for workmanager on this platform.',
    );
  }

  @override
  Future<void> registerProcessingTask(
    String uniqueName,
    String taskName, {
    Duration? initialDelay,
    Map<String, dynamic>? inputData,
    Constraints? constraints,
  }) async {
    throw UnimplementedError(
      'No implementation found for workmanager on this platform.',
    );
  }

  @override
  Future<void> registerHealthResearchTask(
    String uniqueName,
    String taskName, {
    Duration? initialDelay,
    Map<String, dynamic>? inputData,
    Constraints? constraints,
  }) async {
    throw UnimplementedError(
      'No implementation found for workmanager on this platform.',
    );
  }

  @override
  Future<void> registerContinuedProcessingTask(
    String uniqueName,
    String taskName, {
    String? title,
    String? subtitle,
    Map<String, dynamic>? inputData,
  }) async {
    throw UnimplementedError(
      'No implementation found for workmanager on this platform.',
    );
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    throw UnimplementedError(
      'No implementation found for workmanager on this platform.',
    );
  }

  @override
  Future<void> cancelByTag(String tag) async {
    throw UnimplementedError(
      'No implementation found for workmanager on this platform.',
    );
  }

  @override
  Future<void> cancelAll() async {
    throw UnimplementedError(
      'No implementation found for workmanager on this platform.',
    );
  }

  @override
  Future<bool> isScheduledByUniqueName(String uniqueName) async {
    throw UnimplementedError(
      'No implementation found for workmanager on this platform.',
    );
  }

  @override
  Future<String> printScheduledTasks() async {
    throw UnimplementedError(
      'No implementation found for workmanager on this platform.',
    );
  }

  @override
  Future<WorkInfo?> getWorkInfo(String uniqueName) async {
    throw UnimplementedError(
      'No implementation found for workmanager on this platform.',
    );
  }
}
