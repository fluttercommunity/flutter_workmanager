package dev.fluttercommunity.workmanager

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.OutOfQuotaPolicy
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import dev.fluttercommunity.workmanager.BackgroundWorker.Companion.DART_TASK_KEY
import dev.fluttercommunity.workmanager.BackgroundWorker.Companion.IS_IN_DEBUG_MODE_KEY
import java.util.concurrent.TimeUnit
import kotlin.math.max

// Constants
const val DEFAULT_INITIAL_DELAY_SECONDS = 0L
const val DEFAULT_PERIODIC_REFRESH_FREQUENCY_SECONDS =
    PeriodicWorkRequest.MIN_PERIODIC_INTERVAL_MILLIS / 1000
const val DEFAULT_FLEX_INTERVAL_SECONDS =
    PeriodicWorkRequest.MIN_PERIODIC_FLEX_MILLIS / 1000

// Default values
val defaultOneOffExistingWorkPolicy = ExistingWorkPolicy.KEEP
val defaultPeriodExistingWorkPolicy = ExistingPeriodicWorkPolicy.KEEP
val defaultConstraints: Constraints = Constraints.NONE
val defaultOutOfQuotaPolicy: OutOfQuotaPolicy? = null


// BackoffPolicy configuration
data class BackoffPolicyTaskConfig(
    val backoffPolicy: BackoffPolicy,
    private val requestedBackoffDelay: Long,
    private val minBackoffInMillis: Long,
    val backoffDelay: Long = max(minBackoffInMillis, requestedBackoffDelay),
)

// Extension functions to convert Pigeon types to Android WorkManager types
private fun dev.fluttercommunity.workmanager.pigeon.ExistingWorkPolicy.toAndroidWorkPolicy(): ExistingWorkPolicy {
    return when (this) {
        dev.fluttercommunity.workmanager.pigeon.ExistingWorkPolicy.APPEND -> ExistingWorkPolicy.APPEND_OR_REPLACE
        dev.fluttercommunity.workmanager.pigeon.ExistingWorkPolicy.KEEP -> ExistingWorkPolicy.KEEP
        dev.fluttercommunity.workmanager.pigeon.ExistingWorkPolicy.REPLACE -> ExistingWorkPolicy.REPLACE
        dev.fluttercommunity.workmanager.pigeon.ExistingWorkPolicy.UPDATE -> ExistingWorkPolicy.APPEND_OR_REPLACE
    }
}

private fun dev.fluttercommunity.workmanager.pigeon.ExistingWorkPolicy.toAndroidPeriodicWorkPolicy(): ExistingPeriodicWorkPolicy {
    return when (this) {
        dev.fluttercommunity.workmanager.pigeon.ExistingWorkPolicy.APPEND -> ExistingPeriodicWorkPolicy.REPLACE
        dev.fluttercommunity.workmanager.pigeon.ExistingWorkPolicy.KEEP -> ExistingPeriodicWorkPolicy.KEEP
        dev.fluttercommunity.workmanager.pigeon.ExistingWorkPolicy.REPLACE -> ExistingPeriodicWorkPolicy.REPLACE
        dev.fluttercommunity.workmanager.pigeon.ExistingWorkPolicy.UPDATE -> ExistingPeriodicWorkPolicy.UPDATE
    }
}

private fun dev.fluttercommunity.workmanager.pigeon.OutOfQuotaPolicy.toAndroidOutOfQuotaPolicy(): OutOfQuotaPolicy {
    return when (this) {
        dev.fluttercommunity.workmanager.pigeon.OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST -> OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST
        dev.fluttercommunity.workmanager.pigeon.OutOfQuotaPolicy.DROP_WORK_REQUEST -> OutOfQuotaPolicy.DROP_WORK_REQUEST
    }
}

private fun dev.fluttercommunity.workmanager.pigeon.Constraints.toAndroidConstraints(): Constraints {
    val builder = Constraints.Builder()
    
    networkType?.let { builder.setRequiredNetworkType(it.toAndroidNetworkType()) }
    requiresBatteryNotLow?.let { builder.setRequiresBatteryNotLow(it) }
    requiresCharging?.let { builder.setRequiresCharging(it) }
    requiresDeviceIdle?.let { builder.setRequiresDeviceIdle(it) }
    requiresStorageNotLow?.let { builder.setRequiresStorageNotLow(it) }
    
    return builder.build()
}

private fun dev.fluttercommunity.workmanager.pigeon.NetworkType.toAndroidNetworkType(): NetworkType {
    return when (this) {
        dev.fluttercommunity.workmanager.pigeon.NetworkType.CONNECTED -> NetworkType.CONNECTED
        dev.fluttercommunity.workmanager.pigeon.NetworkType.METERED -> NetworkType.METERED
        dev.fluttercommunity.workmanager.pigeon.NetworkType.NOT_REQUIRED -> NetworkType.NOT_REQUIRED
        dev.fluttercommunity.workmanager.pigeon.NetworkType.NOT_ROAMING -> NetworkType.NOT_ROAMING
        dev.fluttercommunity.workmanager.pigeon.NetworkType.UNMETERED -> NetworkType.UNMETERED
        dev.fluttercommunity.workmanager.pigeon.NetworkType.TEMPORARILY_UNMETERED -> NetworkType.TEMPORARILY_UNMETERED
    }
}

private fun dev.fluttercommunity.workmanager.pigeon.BackoffPolicyConfig.toAndroidBackoffPolicyConfig(): BackoffPolicyTaskConfig? {
    return if (backoffPolicy != null && backoffDelayMillis != null) {
        val delayMillis = backoffDelayMillis.toLong()
        BackoffPolicyTaskConfig(
            backoffPolicy = backoffPolicy.toAndroidBackoffPolicy(),
            requestedBackoffDelay = delayMillis,
            minBackoffInMillis = delayMillis,
            backoffDelay = delayMillis
        )
    } else null
}

private fun dev.fluttercommunity.workmanager.pigeon.BackoffPolicy.toAndroidBackoffPolicy(): BackoffPolicy {
    return when (this) {
        dev.fluttercommunity.workmanager.pigeon.BackoffPolicy.EXPONENTIAL -> BackoffPolicy.EXPONENTIAL
        dev.fluttercommunity.workmanager.pigeon.BackoffPolicy.LINEAR -> BackoffPolicy.LINEAR
    }
}

// Helper function to filter out null keys from Map<String?, Any?>
private fun Map<String?, Any?>.filterNotNullKeys(): Map<String, Any> {
    return this.mapNotNull { (key, value) -> 
        if (key != null && value != null) key to value else null 
    }.toMap()
}

class WorkManagerWrapper(val context: Context) {
    private val workManager = WorkManager.getInstance(context)

    fun enqueueOneOffTask(
        request: dev.fluttercommunity.workmanager.pigeon.OneOffTaskRequest,
        isInDebugMode: Boolean = false,
    ) {
        try {
            val oneOffTaskRequest =
                OneTimeWorkRequest
                    .Builder(BackgroundWorker::class.java)
                    .setInputData(buildTaskInputData(request.taskName, isInDebugMode, request.inputData?.filterNotNullKeys()))
                    .setInitialDelay(request.initialDelaySeconds?.toLong() ?: DEFAULT_INITIAL_DELAY_SECONDS, TimeUnit.SECONDS)
                    .setConstraints(request.constraints?.toAndroidConstraints() ?: defaultConstraints)
                    .apply {
                        request.backoffPolicy?.toAndroidBackoffPolicyConfig()?.let { config ->
                            setBackoffCriteria(
                                config.backoffPolicy,
                                config.backoffDelay,
                                TimeUnit.MILLISECONDS,
                            )
                        }
                    }.apply {
                        request.tag?.let(::addTag)
                        request.outOfQuotaPolicy?.toAndroidOutOfQuotaPolicy()?.let(::setExpedited)
                    }.build()
            workManager.enqueueUniqueWork(
                request.uniqueName, 
                request.existingWorkPolicy?.toAndroidWorkPolicy() ?: defaultOneOffExistingWorkPolicy, 
                oneOffTaskRequest
            )
        } catch (e: Exception) {
            throw e
        }
    }

    fun enqueuePeriodicTask(
        request: dev.fluttercommunity.workmanager.pigeon.PeriodicTaskRequest,
        isInDebugMode: Boolean = false,
    ) {
        val periodicTaskRequest =
            PeriodicWorkRequest
                .Builder(
                    BackgroundWorker::class.java,
                    request.frequencySeconds.toLong(),
                    TimeUnit.SECONDS,
                    request.flexIntervalSeconds?.toLong() ?: DEFAULT_FLEX_INTERVAL_SECONDS,
                    TimeUnit.SECONDS,
                ).setInputData(buildTaskInputData(request.taskName, isInDebugMode, request.inputData?.filterNotNullKeys()))
                .setInitialDelay(request.initialDelaySeconds?.toLong() ?: DEFAULT_INITIAL_DELAY_SECONDS, TimeUnit.SECONDS)
                .setConstraints(request.constraints?.toAndroidConstraints() ?: defaultConstraints)
                .apply {
                    request.backoffPolicy?.toAndroidBackoffPolicyConfig()?.let { config ->
                        setBackoffCriteria(
                            config.backoffPolicy,
                            config.backoffDelay,
                            TimeUnit.MILLISECONDS,
                        )
                    }
                }.apply {
                    request.tag?.let(::addTag)
                    // Note: outOfQuotaPolicy is not supported for periodic tasks
                }.build()
        workManager.enqueueUniquePeriodicWork(
            request.uniqueName, 
            request.existingWorkPolicy?.toAndroidPeriodicWorkPolicy() ?: defaultPeriodExistingWorkPolicy, 
            periodicTaskRequest
        )
    }

    private fun buildTaskInputData(
        dartTask: String,
        isInDebugMode: Boolean,
        payload: Map<String, Any>?,
    ): Data {
        val builder =
            Data
                .Builder()
                .putString(DART_TASK_KEY, dartTask)
                .putBoolean(IS_IN_DEBUG_MODE_KEY, isInDebugMode)

        // Add payload data if provided
        payload?.forEach { (key, value) ->
            when (value) {
                is String -> builder.putString("payload_$key", value)
                is Boolean -> builder.putBoolean("payload_$key", value)
                is Int -> builder.putInt("payload_$key", value)
                is Long -> builder.putLong("payload_$key", value)
                is Float -> builder.putFloat("payload_$key", value)
                is Double -> builder.putDouble("payload_$key", value)
                is Array<*> ->
                    builder.putStringArray(
                        "payload_$key",
                        value.filterIsInstance<String>().toTypedArray(),
                    )
                is List<*> ->
                    builder.putStringArray(
                        "payload_$key",
                        value.filterIsInstance<String>().toTypedArray(),
                    )

                is ByteArray -> builder.putByteArray("payload_$key", value)

                else -> {
                    throw IllegalArgumentException(
                        "Unsupported payload type for key '$key': ${value::class.java.simpleName}. " +
                            "Consider converting it to a supported type.",
                    )
                }
            }
        }

        return builder.build()
    }

    fun getWorkInfoByUniqueName(uniqueWorkName: String) = 
        workManager.getWorkInfosForUniqueWork(uniqueWorkName)

    fun cancelByUniqueName(uniqueWorkName: String) = 
        workManager.cancelUniqueWork(uniqueWorkName)

    fun cancelByTag(tag: String) = 
        workManager.cancelAllWorkByTag(tag)

    fun cancelAll() = workManager.cancelAllWork()
}