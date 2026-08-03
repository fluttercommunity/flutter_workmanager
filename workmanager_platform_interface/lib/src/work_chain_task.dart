import 'pigeon/workmanager_api.g.dart';

/// A single step of a sequential work chain registered via
/// [WorkmanagerPlatform.beginUniqueWork].
///
/// Mirrors the per-task configuration of
/// [WorkmanagerPlatform.registerOneOffTask] without the unique name: chain
/// steps are identified by their position in the chain, not by a unique name.
///
/// Work chaining is **Android-only** (it maps to WorkManager's
/// `beginUniqueWork(...).then(...)`); on other platforms
/// [WorkmanagerPlatform.beginUniqueWork] throws an [UnsupportedError].
class WorkChainTask {
  /// Creates a chain step.
  ///
  /// [taskName] is the value that will be returned in the
  /// [BackgroundTaskHandler] while this step runs.
  /// [inputData] is the input data for this step. Valid value types are:
  /// int, bool, double, String and their list.
  /// [initialDelay] is a [Duration] after which this step runs (in addition
  /// to waiting for the previous step to finish).
  /// [constraints] are the requirements that need to be met before this step
  /// runs.
  /// [backoffPolicy] / [backoffPolicyDelay] configure retry behaviour when
  /// this step returns `false` (the plugin maps `false` to WorkManager's
  /// `Result.retry()`, which holds the chain and retries this step).
  /// [tag] is an optional tag that can be used to identify or cancel the
  /// step.
  /// [outOfQuotaPolicy] is the policy to use when the device is out of
  /// quota. (Android only)
  /// [foregroundServiceConfig]: when provided, this step runs as an Android
  /// foreground service for the whole duration of the task, keeping the
  /// process alive for long-running work. See [ForegroundServiceConfig].
  WorkChainTask({
    required this.taskName,
    this.inputData,
    this.initialDelay,
    this.constraints,
    this.backoffPolicy,
    this.backoffPolicyDelay,
    this.tag,
    this.outOfQuotaPolicy,
    this.foregroundServiceConfig,
  });

  /// The value that will be returned in the [BackgroundTaskHandler] while
  /// this step runs.
  final String taskName;

  /// The input data for this step. Valid value types are: int, bool, double,
  /// String and their list.
  final Map<String, dynamic>? inputData;

  /// Delay before this step runs, on top of waiting for the previous step to
  /// finish.
  final Duration? initialDelay;

  /// Requirements that need to be met before this step runs.
  final Constraints? constraints;

  /// The backoff policy to use when retrying this step.
  final BackoffPolicy? backoffPolicy;

  /// The delay for the backoff policy.
  final Duration? backoffPolicyDelay;

  /// Optional tag that can be used to identify or cancel this step.
  final String? tag;

  /// The policy to use when the device is out of quota. (Android only)
  final OutOfQuotaPolicy? outOfQuotaPolicy;

  /// When provided (Android only), this step runs as an Android foreground
  /// service for the whole duration of the task.
  final ForegroundServiceConfig? foregroundServiceConfig;
}
