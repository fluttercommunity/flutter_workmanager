package dev.fluttercommunity.workmanager

import android.content.Context
import android.net.Uri
import android.os.Build
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.ListenableWorker
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.Operation
import androidx.work.OutOfQuotaPolicy
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import dev.fluttercommunity.workmanager.pigeon.TaskStatus
import dev.fluttercommunity.workmanager.pigeon.WorkState
import java.util.concurrent.TimeUnit

// Constants
const val DEFAULT_INITIAL_DELAY_SECONDS = 0L

// Default values
val defaultOneOffExistingWorkPolicy = ExistingWorkPolicy.KEEP
val defaultPeriodExistingWorkPolicy = ExistingPeriodicWorkPolicy.UPDATE
val defaultConstraints: Constraints = Constraints.NONE
val defaultOutOfQuotaPolicy: OutOfQuotaPolicy? = null

/**
 * Builds the [PeriodicWorkRequest] for a periodic task.
 *
 * A flex window is only applied when the caller explicitly provides
 * [flexIntervalSeconds]. Without an explicit flex, WorkManager defaults
 * flex to the full interval, which means the first run is scheduled at
 * `enqueueTime + initialDelay` exactly as requested. Applying a default
 * flex window would push the first run to
 * `initialDelay + (interval - flex)` and look like the initial delay is
 * being ignored.
 */
internal fun createPeriodicWorkRequest(
    taskName: String,
    inputData: Map<String, Any?>?,
    foregroundServiceConfig: dev.fluttercommunity.workmanager.pigeon.ForegroundServiceConfig? = null,
    frequencySeconds: Long,
    flexIntervalSeconds: Long?,
    initialDelaySeconds: Long?,
    constraints: Constraints,
    backoffPolicy: dev.fluttercommunity.workmanager.pigeon.BackoffPolicyConfig?,
    tag: String?,
): PeriodicWorkRequest {
    val builder =
        if (flexIntervalSeconds != null) {
            PeriodicWorkRequest
                .Builder(
                    BackgroundWorker::class.java,
                    frequencySeconds,
                    TimeUnit.SECONDS,
                    flexIntervalSeconds,
                    TimeUnit.SECONDS,
                )
        } else {
            PeriodicWorkRequest
                .Builder(
                    BackgroundWorker::class.java,
                    frequencySeconds,
                    TimeUnit.SECONDS,
                )
        }
    return builder
        .setInputData(buildTaskInputData(taskName, inputData, foregroundServiceConfig))
        .setInitialDelay(
            initialDelaySeconds ?: DEFAULT_INITIAL_DELAY_SECONDS,
            TimeUnit.SECONDS,
        ).setConstraints(constraints)
        .apply {
            backoffPolicy?.let { backoffConfig ->
                if (backoffConfig.backoffPolicy != null && backoffConfig.backoffDelayMillis != null) {
                    setBackoffCriteria(
                        backoffConfig.backoffPolicy.toAndroidBackoffPolicy(),
                        backoffConfig.backoffDelayMillis.toLong(),
                        TimeUnit.MILLISECONDS,
                    )
                }
            }
        }.apply {
            tag?.let(::addTag)
            // Note: outOfQuotaPolicy is not supported for periodic tasks
        }.build()
}

/**
 * Maps a WorkManager [androidx.work.WorkInfo] to the Pigeon transport model
 * for the query API.
 *
 * The state mapping is the cross-platform subset of `WorkInfo.State`;
 * BLOCKED (waiting on prerequisites) is reported as [WorkState.SCHEDULED].
 * `lastFinishedAtMillis` is always null on Android: WorkManager does not
 * expose a finish timestamp.
 */
internal fun androidx.work.WorkInfo.toWorkInfoData(uniqueName: String): dev.fluttercommunity.workmanager.pigeon.WorkInfoData {
    val workState =
        when (state) {
            androidx.work.WorkInfo.State.ENQUEUED, androidx.work.WorkInfo.State.BLOCKED -> WorkState.SCHEDULED
            androidx.work.WorkInfo.State.RUNNING -> WorkState.RUNNING
            androidx.work.WorkInfo.State.SUCCEEDED -> WorkState.SUCCEEDED
            androidx.work.WorkInfo.State.FAILED -> WorkState.FAILED
            androidx.work.WorkInfo.State.CANCELLED -> WorkState.CANCELLED
        }
    return dev.fluttercommunity.workmanager.pigeon.WorkInfoData(
        uniqueName = uniqueName,
        state = workState,
        isPeriodic = periodicityInfo != null,
        taskName = outputData.getString(BackgroundWorker.DART_TASK_KEY),
        tags = tags.sorted().map { it as String? },
        lastFinishedAtMillis = null,
    )
}

/**
 * Builds a [OneTimeWorkRequest] for the given task configuration.
 *
 * Shared by one-off registrations ([WorkManagerWrapper.enqueueOneOffTask]) and
 * work chains ([WorkManagerWrapper.beginUniqueWork]) so both reuse the same
 * payload, delay, constraints, backoff, tag and expedited handling.
 */
internal fun createOneTimeWorkRequest(
    workerClass: Class<out ListenableWorker>,
    taskName: String,
    inputData: Map<String, Any?>?,
    foregroundServiceConfig: dev.fluttercommunity.workmanager.pigeon.ForegroundServiceConfig? = null,
    initialDelaySeconds: Long?,
    constraints: Constraints,
    backoffPolicy: dev.fluttercommunity.workmanager.pigeon.BackoffPolicyConfig?,
    tag: String?,
    outOfQuotaPolicy: dev.fluttercommunity.workmanager.pigeon.OutOfQuotaPolicy?,
): OneTimeWorkRequest =
    OneTimeWorkRequest
        .Builder(workerClass)
        .setInputData(buildTaskInputData(taskName, inputData, foregroundServiceConfig))
        .setInitialDelay(
            initialDelaySeconds ?: DEFAULT_INITIAL_DELAY_SECONDS,
            TimeUnit.SECONDS,
        ).setConstraints(constraints)
        .apply {
            backoffPolicy?.let { backoffConfig ->
                if (backoffConfig.backoffPolicy != null && backoffConfig.backoffDelayMillis != null) {
                    setBackoffCriteria(
                        backoffConfig.backoffPolicy.toAndroidBackoffPolicy(),
                        backoffConfig.backoffDelayMillis.toLong(),
                        TimeUnit.MILLISECONDS,
                    )
                }
            }
        }.apply {
            tag?.let(::addTag)
            // No implicit setExpedited: since 0.10.2 expedited work is opt-in
            // (see createOneOffWorkRequest); chains don't expose it yet.
        }.build()

// Extension functions to convert Pigeon types to Android WorkManager types
private fun dev.fluttercommunity.workmanager.pigeon.ExistingWorkPolicy.toAndroidWorkPolicy(): ExistingWorkPolicy =
    when (this) {
        dev.fluttercommunity.workmanager.pigeon.ExistingWorkPolicy.APPEND -> ExistingWorkPolicy.APPEND_OR_REPLACE
        dev.fluttercommunity.workmanager.pigeon.ExistingWorkPolicy.KEEP -> ExistingWorkPolicy.KEEP
        dev.fluttercommunity.workmanager.pigeon.ExistingWorkPolicy.REPLACE -> ExistingWorkPolicy.REPLACE
        dev.fluttercommunity.workmanager.pigeon.ExistingWorkPolicy.UPDATE -> ExistingWorkPolicy.APPEND_OR_REPLACE
    }

private fun dev.fluttercommunity.workmanager.pigeon.ExistingPeriodicWorkPolicy.toAndroidPeriodicWorkPolicy(): ExistingPeriodicWorkPolicy =
    when (this) {
        dev.fluttercommunity.workmanager.pigeon.ExistingPeriodicWorkPolicy.KEEP -> ExistingPeriodicWorkPolicy.KEEP
        dev.fluttercommunity.workmanager.pigeon.ExistingPeriodicWorkPolicy.REPLACE -> ExistingPeriodicWorkPolicy.REPLACE
        dev.fluttercommunity.workmanager.pigeon.ExistingPeriodicWorkPolicy.UPDATE -> ExistingPeriodicWorkPolicy.UPDATE
    }

private fun dev.fluttercommunity.workmanager.pigeon.OutOfQuotaPolicy.toAndroidOutOfQuotaPolicy(): OutOfQuotaPolicy =
    when (this) {
        dev.fluttercommunity.workmanager.pigeon.OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST ->
            OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST
        dev.fluttercommunity.workmanager.pigeon.OutOfQuotaPolicy.DROP_WORK_REQUEST -> OutOfQuotaPolicy.DROP_WORK_REQUEST
    }

internal fun dev.fluttercommunity.workmanager.pigeon.Constraints.toAndroidConstraints(): Constraints {
    val builder = Constraints.Builder()

    networkType?.let { builder.setRequiredNetworkType(it.toAndroidNetworkType()) }
    requiresBatteryNotLow?.let { builder.setRequiresBatteryNotLow(it) }
    requiresCharging?.let { builder.setRequiresCharging(it) }
    requiresDeviceIdle?.let {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            builder.setRequiresDeviceIdle(it)
        }
    }
    requiresStorageNotLow?.let { builder.setRequiresStorageNotLow(it) }
    contentUriTriggers?.forEach { trigger ->
        trigger?.let {
            if (isContentUriTriggerSupported()) {
                builder.addContentUriTrigger(Uri.parse(it.uri), it.triggerForDescendants)
            }
        }
    }

    return builder.build()
}

/**
 * Content URI trigger constraints are only supported on Android 7.0 (API 24)+;
 * on older versions JobScheduler silently drops them.
 */
internal fun isContentUriTriggerSupported(sdkInt: Int = Build.VERSION.SDK_INT): Boolean = sdkInt >= Build.VERSION_CODES.N

private fun dev.fluttercommunity.workmanager.pigeon.NetworkType.toAndroidNetworkType(): NetworkType =
    when (this) {
        dev.fluttercommunity.workmanager.pigeon.NetworkType.CONNECTED -> NetworkType.CONNECTED
        dev.fluttercommunity.workmanager.pigeon.NetworkType.METERED -> NetworkType.METERED
        dev.fluttercommunity.workmanager.pigeon.NetworkType.NOT_REQUIRED -> NetworkType.NOT_REQUIRED
        dev.fluttercommunity.workmanager.pigeon.NetworkType.NOT_ROAMING -> NetworkType.NOT_ROAMING
        dev.fluttercommunity.workmanager.pigeon.NetworkType.UNMETERED -> NetworkType.UNMETERED
        dev.fluttercommunity.workmanager.pigeon.NetworkType.TEMPORARILY_UNMETERED -> {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                NetworkType.TEMPORARILY_UNMETERED
            } else {
                NetworkType.UNMETERED
            }
        }
    }

private fun dev.fluttercommunity.workmanager.pigeon.BackoffPolicy.toAndroidBackoffPolicy(): BackoffPolicy =
    when (this) {
        dev.fluttercommunity.workmanager.pigeon.BackoffPolicy.EXPONENTIAL -> BackoffPolicy.EXPONENTIAL
        dev.fluttercommunity.workmanager.pigeon.BackoffPolicy.LINEAR -> BackoffPolicy.LINEAR
    }

// Helper function to filter out null keys from Map<String?, Any?>
private fun Map<String?, Any?>.filterNotNullKeys(): Map<String, Any> =
    this
        .mapNotNull { (key, value) ->
            if (key != null && value != null) key to value else null
        }.toMap()

internal fun createOneOffWorkRequest(request: dev.fluttercommunity.workmanager.pigeon.OneOffTaskRequest): OneTimeWorkRequest {
    val builder =
        OneTimeWorkRequest
            .Builder(BackgroundWorker::class.java)
            .setInputData(
                buildTaskInputData(
                    request.taskName,
                    request.inputData?.filterNotNullKeys(),
                    request.foregroundServiceConfig,
                ),
            ).setInitialDelay(
                request.initialDelaySeconds ?: DEFAULT_INITIAL_DELAY_SECONDS,
                TimeUnit.SECONDS,
            ).setConstraints(
                request.constraints?.toAndroidConstraints() ?: defaultConstraints,
            ).apply {
                request.backoffPolicy?.let { backoffConfig ->
                    if (backoffConfig.backoffPolicy != null && backoffConfig.backoffDelayMillis != null) {
                        setBackoffCriteria(
                            backoffConfig.backoffPolicy.toAndroidBackoffPolicy(),
                            backoffConfig.backoffDelayMillis.toLong(),
                            TimeUnit.MILLISECONDS,
                        )
                    }
                }
            }.apply {
                request.tag?.let(::addTag)
                if (request.expedited == true) {
                    setExpedited(
                        request.outOfQuotaPolicy?.toAndroidOutOfQuotaPolicy()
                            ?: OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST,
                    )
                }
            }
    return builder.build()
}

class WorkManagerWrapper(
    val context: Context,
    private val workerClass: Class<out ListenableWorker> = BackgroundWorker::class.java,
) {
    private val workManager = WorkManager.getInstance(context)

    fun enqueueOneOffTask(request: dev.fluttercommunity.workmanager.pigeon.OneOffTaskRequest) {
        try {
            val oneOffTaskRequest = createOneOffWorkRequest(request)

            workManager.enqueueUniqueWork(
                request.uniqueName,
                request.existingWorkPolicy?.toAndroidWorkPolicy()
                    ?: defaultOneOffExistingWorkPolicy,
                oneOffTaskRequest,
            )

            val taskInfo =
                TaskDebugInfo(
                    taskName = request.taskName,
                    uniqueName = request.uniqueName,
                    inputData = request.inputData?.filterNotNullKeys(),
                    startTime = System.currentTimeMillis(),
                )
            WorkmanagerDebug.onTaskStatusUpdate(context, taskInfo, TaskStatus.SCHEDULED)
        } catch (e: Exception) {
            throw e
        }
    }

    fun enqueuePeriodicTask(request: dev.fluttercommunity.workmanager.pigeon.PeriodicTaskRequest) {
        val periodicTaskRequest =
            createPeriodicWorkRequest(
                taskName = request.taskName,
                inputData = request.inputData?.filterNotNullKeys(),
                foregroundServiceConfig = request.foregroundServiceConfig,
                frequencySeconds = request.frequencySeconds,
                flexIntervalSeconds = request.flexIntervalSeconds,
                initialDelaySeconds = request.initialDelaySeconds,
                constraints = request.constraints?.toAndroidConstraints() ?: defaultConstraints,
                backoffPolicy = request.backoffPolicy,
                tag = request.tag,
            )
        workManager.enqueueUniquePeriodicWork(
            request.uniqueName,
            request.existingWorkPolicy?.toAndroidPeriodicWorkPolicy()
                ?: defaultPeriodExistingWorkPolicy,
            periodicTaskRequest,
        )

        val taskInfo =
            TaskDebugInfo(
                taskName = request.taskName,
                uniqueName = request.uniqueName,
                inputData = request.inputData?.filterNotNullKeys(),
                startTime = System.currentTimeMillis(),
            )
        WorkmanagerDebug.onTaskStatusUpdate(context, taskInfo, TaskStatus.SCHEDULED)
    }

    /**
     * Enqueues a sequential chain of one-off tasks under a single unique name.
     *
     * Mirrors WorkManager's `beginUniqueWork(name, policy, first).then(...).enqueue()`:
     * - The first task starts the chain.
     * - Every following task runs only after the previous one finished with
     *   `Result.success()` (strict ordering).
     * - A step returning `Result.retry()` holds the chain and is retried with
     *   its backoff policy.
     * - A step returning `Result.failure()` stops the chain; WorkManager
     *   cancels the remaining steps.
     */
    fun beginUniqueWork(request: dev.fluttercommunity.workmanager.pigeon.UniqueWorkChainRequest): Operation {
        require(request.tasks.isNotEmpty()) { "Work chain must contain at least one task" }

        val steps = request.tasks.mapNotNull { it }
        val workRequests =
            steps.map { step ->
                createOneTimeWorkRequest(
                    workerClass = workerClass,
                    taskName = step.taskName,
                    inputData = step.inputData?.filterNotNullKeys(),
                    foregroundServiceConfig = step.foregroundServiceConfig,
                    initialDelaySeconds = step.initialDelaySeconds,
                    constraints = step.constraints?.toAndroidConstraints() ?: defaultConstraints,
                    backoffPolicy = step.backoffPolicy,
                    tag = step.tag,
                    outOfQuotaPolicy = step.outOfQuotaPolicy,
                )
            }

        var continuation =
            workManager.beginUniqueWork(
                request.uniqueName,
                request.existingWorkPolicy?.toAndroidWorkPolicy()
                    ?: defaultOneOffExistingWorkPolicy,
                workRequests.first(),
            )
        workRequests.drop(1).forEach { continuation = continuation.then(it) }
        val operation = continuation.enqueue()

        steps.forEach { step ->
            val taskInfo =
                TaskDebugInfo(
                    taskName = step.taskName,
                    uniqueName = request.uniqueName,
                    inputData = step.inputData?.filterNotNullKeys(),
                    startTime = System.currentTimeMillis(),
                )
            WorkmanagerDebug.onTaskStatusUpdate(context, taskInfo, TaskStatus.SCHEDULED)
        }
        return operation
    }

    fun getWorkInfoByUniqueName(uniqueWorkName: String) = workManager.getWorkInfosForUniqueWork(uniqueWorkName)

    fun cancelByUniqueName(uniqueWorkName: String) = workManager.cancelUniqueWork(uniqueWorkName)

    fun cancelByTag(tag: String) = workManager.cancelAllWorkByTag(tag)

    fun cancelAll() = workManager.cancelAllWork()
}
