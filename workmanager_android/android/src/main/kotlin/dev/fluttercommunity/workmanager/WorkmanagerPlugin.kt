package dev.fluttercommunity.workmanager

import dev.fluttercommunity.workmanager.pigeon.InitializeRequest
import dev.fluttercommunity.workmanager.pigeon.OneOffTaskRequest
import dev.fluttercommunity.workmanager.pigeon.PeriodicTaskRequest
import dev.fluttercommunity.workmanager.pigeon.ProcessingTaskRequest
import dev.fluttercommunity.workmanager.pigeon.WorkmanagerHostApi
import io.flutter.embedding.engine.plugins.FlutterPlugin

private const val INIT_REQUIRED =
    "You have not properly initialized the Flutter WorkManager Package. " +
        "You should ensure you have called the 'initialize' function first!"

/**
 * Pigeon-based implementation of WorkmanagerHostApi for Android.
 * Replaces the manual method channel and data extraction approach.
 */
class WorkmanagerPlugin :
    FlutterPlugin,
    WorkmanagerHostApi {
    private var workManagerWrapper: WorkManagerWrapper? = null
    private lateinit var preferenceManager: SharedPreferenceHelper

    private var currentDispatcherHandle: Long = -1L

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        preferenceManager =
            SharedPreferenceHelper(
                binding.applicationContext,
                object : SharedPreferenceHelper.DispatcherHandleListener {
                    override fun onDispatcherHandleChanged(handle: Long) {
                        currentDispatcherHandle = handle
                    }
                },
            )
        workManagerWrapper = WorkManagerWrapper(binding.applicationContext)
        WorkmanagerHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        WorkmanagerHostApi.setUp(binding.binaryMessenger, null)
        workManagerWrapper = null
    }

    override fun initialize(
        request: InitializeRequest,
        callback: (Result<Unit>) -> Unit,
    ) {
        try {
            val handle = request.callbackHandle

            // Save to SharedPreferences
            preferenceManager.saveCallbackDispatcherHandleKey(handle)

            // Update the local variable to match
            currentDispatcherHandle = handle

            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun registerOneOffTask(
        request: OneOffTaskRequest,
        callback: (Result<Unit>) -> Unit,
    ) {
        if (currentDispatcherHandle == -1L) {
            callback(Result.failure(Exception(INIT_REQUIRED)))
            return
        }

        try {
            workManagerWrapper!!.enqueueOneOffTask(request = request)
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun registerPeriodicTask(
        request: PeriodicTaskRequest,
        callback: (Result<Unit>) -> Unit,
    ) {
        if (currentDispatcherHandle == -1L) {
            callback(Result.failure(Exception(INIT_REQUIRED)))
            return
        }

        try {
            workManagerWrapper!!.enqueuePeriodicTask(request = request)
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun registerProcessingTask(
        request: ProcessingTaskRequest,
        callback: (Result<Unit>) -> Unit,
    ) {
        // Processing tasks are iOS-specific
        callback(Result.failure(UnsupportedOperationException("Processing tasks are not supported on Android")))
    }

    override fun cancelByUniqueName(
        uniqueName: String,
        callback: (Result<Unit>) -> Unit,
    ) {
        try {
            workManagerWrapper!!.cancelByUniqueName(uniqueName)
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun cancelByTag(
        tag: String,
        callback: (Result<Unit>) -> Unit,
    ) {
        try {
            workManagerWrapper!!.cancelByTag(tag)
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun cancelAll(callback: (Result<Unit>) -> Unit) {
        try {
            workManagerWrapper!!.cancelAll()
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun isScheduledByUniqueName(
        uniqueName: String,
        callback: (Result<Boolean>) -> Unit,
    ) {
        try {
            val workInfos = workManagerWrapper!!.getWorkInfoByUniqueName(uniqueName).get()
            val scheduled =
                workInfos.isNotEmpty() &&
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
