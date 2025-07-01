package dev.fluttercommunity.workmanager

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
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

// Helper function
private fun Context.workManager() = WorkManager.getInstance(this)

// BackoffPolicy configuration
data class BackoffPolicyTaskConfig(
    val backoffPolicy: BackoffPolicy,
    private val requestedBackoffDelay: Long,
    private val minBackoffInMillis: Long,
    val backoffDelay: Long = max(minBackoffInMillis, requestedBackoffDelay),
)

object WM {
    fun enqueueOneOffTask(
        context: Context,
        uniqueName: String,
        dartTask: String,
        payload: Map<String, Any>? = null,
        tag: String? = null,
        isInDebugMode: Boolean = false,
        existingWorkPolicy: ExistingWorkPolicy = defaultOneOffExistingWorkPolicy,
        initialDelaySeconds: Long = DEFAULT_INITIAL_DELAY_SECONDS,
        constraintsConfig: Constraints = defaultConstraints,
        outOfQuotaPolicy: OutOfQuotaPolicy? = defaultOutOfQuotaPolicy,
        backoffPolicyConfig: BackoffPolicyTaskConfig?,
    ) {
        try {
            val oneOffTaskRequest =
                OneTimeWorkRequest
                    .Builder(BackgroundWorker::class.java)
                    .setInputData(buildTaskInputData(dartTask, isInDebugMode, payload))
                    .setInitialDelay(initialDelaySeconds, TimeUnit.SECONDS)
                    .setConstraints(constraintsConfig)
                    .apply {
                        if (backoffPolicyConfig != null) {
                            setBackoffCriteria(
                                backoffPolicyConfig.backoffPolicy,
                                backoffPolicyConfig.backoffDelay,
                                TimeUnit.MILLISECONDS,
                            )
                        }
                    }.apply {
                        tag?.let(::addTag)
                        outOfQuotaPolicy?.let(::setExpedited)
                    }.build()
            context
                .workManager()
                .enqueueUniqueWork(uniqueName, existingWorkPolicy, oneOffTaskRequest)
        } catch (e: Exception) {
            throw e
        }
    }

    fun enqueuePeriodicTask(
        context: Context,
        uniqueName: String,
        dartTask: String,
        payload: Map<String, Any>? = null,
        tag: String? = null,
        frequencyInSeconds: Long = DEFAULT_PERIODIC_REFRESH_FREQUENCY_SECONDS,
        flexIntervalInSeconds: Long = DEFAULT_FLEX_INTERVAL_SECONDS,
        isInDebugMode: Boolean = false,
        existingWorkPolicy: ExistingPeriodicWorkPolicy = defaultPeriodExistingWorkPolicy,
        initialDelaySeconds: Long = DEFAULT_INITIAL_DELAY_SECONDS,
        constraintsConfig: Constraints = defaultConstraints,
        outOfQuotaPolicy: OutOfQuotaPolicy? = defaultOutOfQuotaPolicy,
        backoffPolicyConfig: BackoffPolicyTaskConfig?,
    ) {
        val periodicTaskRequest =
            PeriodicWorkRequest
                .Builder(
                    BackgroundWorker::class.java,
                    frequencyInSeconds,
                    TimeUnit.SECONDS,
                    flexIntervalInSeconds,
                    TimeUnit.SECONDS,
                ).setInputData(buildTaskInputData(dartTask, isInDebugMode, payload))
                .setInitialDelay(initialDelaySeconds, TimeUnit.SECONDS)
                .setConstraints(constraintsConfig)
                .apply {
                    if (backoffPolicyConfig != null) {
                        setBackoffCriteria(
                            backoffPolicyConfig.backoffPolicy,
                            backoffPolicyConfig.backoffDelay,
                            TimeUnit.MILLISECONDS,
                        )
                    }
                }.apply {
                    tag?.let(::addTag)
                    outOfQuotaPolicy?.let(::setExpedited)
                }.build()
        context
            .workManager()
            .enqueueUniquePeriodicWork(uniqueName, existingWorkPolicy, periodicTaskRequest)
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

    fun getWorkInfoByUniqueName(
        context: Context,
        uniqueWorkName: String,
    ) = context.workManager().getWorkInfosForUniqueWork(uniqueWorkName)

    fun cancelByUniqueName(
        context: Context,
        uniqueWorkName: String,
    ) = context.workManager().cancelUniqueWork(uniqueWorkName)

    fun cancelByTag(
        context: Context,
        tag: String,
    ) = context.workManager().cancelAllWorkByTag(tag)

    fun cancelAll(context: Context) = context.workManager().cancelAllWork()
}