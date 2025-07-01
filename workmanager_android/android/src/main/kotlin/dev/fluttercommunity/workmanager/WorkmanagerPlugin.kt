package dev.fluttercommunity.workmanager

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OutOfQuotaPolicy
import dev.fluttercommunity.workmanager.pigeon.BackoffPolicyConfig
import dev.fluttercommunity.workmanager.pigeon.InitializeRequest
import dev.fluttercommunity.workmanager.pigeon.OneOffTaskRequest
import dev.fluttercommunity.workmanager.pigeon.PeriodicTaskRequest
import dev.fluttercommunity.workmanager.pigeon.ProcessingTaskRequest
import dev.fluttercommunity.workmanager.pigeon.WorkmanagerHostApi
import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Pigeon-based implementation of WorkmanagerHostApi for Android.
 * Replaces the manual method channel and data extraction approach.
 */
class WorkmanagerPlugin : FlutterPlugin, WorkmanagerHostApi {
    private var workManagerWrapper: WorkManagerWrapper? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        workManagerWrapper = WorkManagerWrapper(binding.applicationContext)
        WorkmanagerHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        WorkmanagerHostApi.setUp(binding.binaryMessenger, null)
        workManagerWrapper = null
    }

    override fun initialize(request: InitializeRequest, callback: (Result<Unit>) -> Unit) {
        try {
            SharedPreferenceHelper.saveCallbackDispatcherHandleKey(workManagerWrapper!!.context, request.callbackHandle.toLong())
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun registerOneOffTask(request: OneOffTaskRequest, callback: (Result<Unit>) -> Unit) {
        if (!SharedPreferenceHelper.hasCallbackHandle(workManagerWrapper!!.context)) {
            callback(Result.failure(Exception(
                "You have not properly initialized the Flutter WorkManager Package. " +
                "You should ensure you have called the 'initialize' function first!"
            )))
            return
        }

        try {
            workManagerWrapper!!.enqueueOneOffTask(
                uniqueName = request.uniqueName,
                dartTask = request.taskName,
                payload = request.inputData?.filterNotNullKeys(),
                tag = request.tag,
                isInDebugMode = false, // TODO: Get from initialization
                existingWorkPolicy = request.existingWorkPolicy?.toAndroidWorkPolicy() ?: ExistingWorkPolicy.KEEP,
                initialDelaySeconds = request.initialDelaySeconds?.toLong() ?: 0L,
                constraintsConfig = request.constraints?.toAndroidConstraints() ?: Constraints.NONE,
                outOfQuotaPolicy = request.outOfQuotaPolicy?.toAndroidOutOfQuotaPolicy(),
                backoffPolicyConfig = request.backoffPolicy?.toAndroidBackoffPolicyConfig(),
            )
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun registerPeriodicTask(request: PeriodicTaskRequest, callback: (Result<Unit>) -> Unit) {
        if (!SharedPreferenceHelper.hasCallbackHandle(workManagerWrapper!!.context)) {
            callback(Result.failure(Exception(
                "You have not properly initialized the Flutter WorkManager Package. " +
                "You should ensure you have called the 'initialize' function first!"
            )))
            return
        }

        try {
            workManagerWrapper!!.enqueuePeriodicTask(
                uniqueName = request.uniqueName,
                dartTask = request.taskName,
                payload = request.inputData?.filterNotNullKeys(),
                tag = request.tag,
                frequencyInSeconds = request.frequencySeconds.toLong(),
                flexIntervalInSeconds = request.flexIntervalSeconds?.toLong() ?: DEFAULT_FLEX_INTERVAL_SECONDS,
                isInDebugMode = false, // TODO: Get from initialization
                existingWorkPolicy = request.existingWorkPolicy?.toAndroidPeriodicWorkPolicy() ?: ExistingPeriodicWorkPolicy.KEEP,
                initialDelaySeconds = request.initialDelaySeconds?.toLong() ?: 0L,
                constraintsConfig = request.constraints?.toAndroidConstraints() ?: Constraints.NONE,
                outOfQuotaPolicy = null, // Not supported for periodic tasks
                backoffPolicyConfig = request.backoffPolicy?.toAndroidBackoffPolicyConfig(),
            )
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun registerProcessingTask(request: ProcessingTaskRequest, callback: (Result<Unit>) -> Unit) {
        // Processing tasks are iOS-specific
        callback(Result.failure(UnsupportedOperationException("Processing tasks are not supported on Android")))
    }

    override fun cancelByUniqueName(uniqueName: String, callback: (Result<Unit>) -> Unit) {
        try {
            workManagerWrapper!!.cancelByUniqueName(uniqueName)
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun cancelByTag(tag: String, callback: (Result<Unit>) -> Unit) {
        val wrapper = workManagerWrapper
        if (wrapper == null) {
            callback(Result.failure(Exception("Plugin not attached to engine")))
            return
        }

        try {
            workManagerWrapper!!.cancelByTag(tag)
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun cancelAll(callback: (Result<Unit>) -> Unit) {
        val wrapper = workManagerWrapper
        if (wrapper == null) {
            callback(Result.failure(Exception("Plugin not attached to engine")))
            return
        }

        try {
            workManagerWrapper!!.cancelAll()
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun isScheduledByUniqueName(uniqueName: String, callback: (Result<Boolean>) -> Unit) {
        try {
            val workInfos = workManagerWrapper!!.getWorkInfoByUniqueName(uniqueName).get()
            val scheduled = workInfos.isNotEmpty() && 
                workInfos.all { it.state == androidx.work.WorkInfo.State.ENQUEUED || it.state == androidx.work.WorkInfo.State.RUNNING }
            callback(Result.success(scheduled))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun printScheduledTasks(callback: (Result<String>) -> Unit) {
        // Not supported on Android
        callback(Result.failure(UnsupportedOperationException("printScheduledTasks is not supported on Android")))
    }
}

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

private fun BackoffPolicyConfig.toAndroidBackoffPolicyConfig(): BackoffPolicyTaskConfig? {
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
