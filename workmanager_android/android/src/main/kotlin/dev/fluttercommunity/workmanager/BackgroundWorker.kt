package dev.fluttercommunity.workmanager

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.work.ListenableWorker
import androidx.work.WorkerParameters
import com.google.common.util.concurrent.ListenableFuture
import dev.fluttercommunity.workmanager.pigeon.ForegroundServiceConfig
import dev.fluttercommunity.workmanager.pigeon.TaskStatus
import dev.fluttercommunity.workmanager.pigeon.WorkmanagerFlutterApi
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.view.FlutterCallbackInformation
import java.security.SecureRandom
import java.util.concurrent.Executor
import java.util.concurrent.atomic.AtomicBoolean

/**
 * A simple worker that posts your input back to your Flutter application.
 *
 * It will block the background thread until a value of either true or false is received back from Flutter code.
 */
class BackgroundWorker(
    applicationContext: Context,
    private val workerParams: WorkerParameters,
) : ListenableWorker(applicationContext, workerParams) {
    private lateinit var flutterApi: WorkmanagerFlutterApi

    companion object {
        const val PAYLOAD_KEY = "dev.fluttercommunity.workmanager.INPUT_DATA"
        const val DART_TASK_KEY = "dev.fluttercommunity.workmanager.DART_TASK"
    }

    private val payload
        get() = decodePayload(workerParams.inputData.keyValueMap)

    private val dartTask
        get() = workerParams.inputData.getString(DART_TASK_KEY)

    private val runAttemptCount = workerParams.runAttemptCount
    private val randomThreadIdentifier = SecureRandom().nextInt()
    private var engine: FlutterEngine? = null

    private var startTime: Long = 0

    private var completer: CallbackToFutureAdapter.Completer<Result>? = null

    private var resolvableFuture =
        CallbackToFutureAdapter.getFuture { completer ->
            this.completer = completer
            null
        }

    private val foregroundServiceConfig: ForegroundServiceConfig? =
        decodeForegroundServiceConfig(workerParams.inputData)

    private val directExecutor = Executor { it.run() }

    override fun startWork(): ListenableFuture<Result> {
        startTime = System.currentTimeMillis()

        // Promote the worker to a foreground service right away when a config
        // was provided at registration time, so the notification (and the
        // process priority boost) are in place while the Dart engine starts.
        val foregroundFuture =
            foregroundServiceConfig?.let { config ->
                setForegroundAsync(createForegroundInfo(applicationContext, config))
            }

        val flutterLoader: FlutterLoader = FlutterInjector.instance().flutterLoader()

        if (!flutterLoader.initialized()) {
            flutterLoader.startInitialization(applicationContext)
        }

        flutterLoader.ensureInitializationCompleteAsync(
            applicationContext,
            null,
            Handler(Looper.getMainLooper()),
        ) {
            engine = FlutterEngine(applicationContext)
            val callbackHandle = SharedPreferenceHelper.getCallbackHandle(applicationContext)
            val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)

            if (callbackInfo == null) {
                val exception = IllegalStateException("Failed to resolve Dart callback for handle $callbackHandle")
                WorkmanagerDebug.onExceptionEncountered(applicationContext, null, exception)
                completer?.set(Result.failure())
                return@ensureInitializationCompleteAsync
            }

            val localDartTask = dartTask

            if (localDartTask == null) {
                val exception = IllegalStateException("Dart task is null")
                WorkmanagerDebug.onExceptionEncountered(applicationContext, null, exception)
                completer?.set(Result.failure())
                return@ensureInitializationCompleteAsync
            }

            val dartBundlePath = flutterLoader.findAppBundlePath()

            val taskInfo =
                TaskDebugInfo(
                    taskName = localDartTask,
                    inputData = payload,
                    startTime = startTime,
                    callbackHandle = callbackHandle,
                    callbackInfo = callbackInfo?.callbackName,
                )

            val startStatus = if (runAttemptCount > 0) TaskStatus.RETRYING else TaskStatus.STARTED
            WorkmanagerDebug.onTaskStatusUpdate(applicationContext, taskInfo, startStatus)

            engine?.let { engine ->
                flutterApi = WorkmanagerFlutterApi(engine.dartExecutor.binaryMessenger)

                engine.dartExecutor.executeDartCallback(
                    DartExecutor.DartCallback(
                        applicationContext.assets,
                        dartBundlePath,
                        callbackInfo,
                    ),
                )

                // Initialize the background channel
                flutterApi.backgroundChannelInitialized {
                    // Channel is initialized, now execute the task
                    executeBackgroundTask()
                }
            }
        }

        return combineForegroundWithResult(foregroundFuture)
    }

    /**
     * WorkManager requires the future returned by [setForegroundAsync] to be
     * part of the future returned from [startWork]. The combined future only
     * completes once both the foreground service has been started and the
     * Dart task has finished. A failure to start the foreground service never
     * fails the worker; it is reported through the debug handler and the task
     * simply keeps running as a regular background worker.
     */
    private fun combineForegroundWithResult(foregroundFuture: ListenableFuture<*>?): ListenableFuture<Result> {
        if (foregroundFuture == null) {
            return resolvableFuture
        }

        return CallbackToFutureAdapter.getFuture { combinedCompleter ->
            val completed = AtomicBoolean(false)
            val listener =
                Runnable {
                    if (foregroundFuture.isDone && resolvableFuture.isDone && completed.compareAndSet(false, true)) {
                        foregroundFuture.takeUnless { it.isCancelled }?.let {
                            try {
                                it.get()
                            } catch (e: Exception) {
                                WorkmanagerDebug.onExceptionEncountered(applicationContext, null, e)
                            }
                        }
                        combinedCompleter.set(resolvableFuture.get())
                    }
                }
            foregroundFuture.addListener(listener, directExecutor)
            resolvableFuture.addListener(listener, directExecutor)
            null
        }
    }

    override fun onStopped() {
        val localDartTask = dartTask
        val stopReason = workerStopReason()

        // Notify the running Dart callback that WorkManager stopped the worker
        // (cancelled, timed out, preempted, ...) so it can persist state or
        // release resources before the engine is torn down.
        if (localDartTask != null && ::flutterApi.isInitialized && engine != null) {
            try {
                flutterApi.onTaskStopped(localDartTask, stopReason.toLong()) {
                    stopEngine(null, stopReason = stopReason)
                }
                return
            } catch (e: Exception) {
                WorkmanagerDebug.onExceptionEncountered(
                    applicationContext,
                    TaskDebugInfo(
                        taskName = localDartTask,
                        inputData = payload,
                        startTime = startTime,
                    ),
                    e,
                )
            }
        }
        stopEngine(null, stopReason = stopReason)
    }

    private fun stopEngine(
        result: Result?,
        errorMessage: String? = null,
        stopReason: Int = StopReasonUtils.STOP_REASON_UNKNOWN,
    ) {
        val fetchDuration = System.currentTimeMillis() - startTime

        val localDartTask = dartTask

        if (localDartTask == null) {
            val exception = IllegalStateException("Dart task is null")
            WorkmanagerDebug.onExceptionEncountered(applicationContext, null, exception)
            completer?.set(Result.failure())
            return
        }

        val taskInfo =
            TaskDebugInfo(
                taskName = localDartTask,
                inputData = payload,
                startTime = startTime,
            )

        val taskResult =
            TaskResult(
                success = result is Result.Success,
                duration = fetchDuration,
                error =
                    when (result) {
                        is Result.Failure -> errorMessage ?: "Task failed"
                        else -> null
                    },
            )

        val status =
            when (result) {
                is Result.Success -> TaskStatus.COMPLETED
                is Result.Retry -> TaskStatus.RESCHEDULED
                else -> StopReasonUtils.toTaskStatus(stopReason)
            }
        WorkmanagerDebug.onTaskStatusUpdate(applicationContext, taskInfo, status, taskResult)

        // No result indicates we were signalled to stop by WorkManager.  The result is already
        // STOPPED, so no need to resolve another one.
        if (result != null) {
            this.completer?.set(result)
        }

        // If stopEngine is called from `onStopped`, it may not be from the main thread.
        Handler(Looper.getMainLooper()).post {
            engine?.destroy()
            engine = null
        }
    }

    /**
     * Returns the WorkManager stop reason for the current stop.
     *
     * The value is only populated on Android 12 (API 31) and newer; on older
     * versions [StopReasonUtils.STOP_REASON_UNKNOWN] is reported.
     */
    private fun workerStopReason(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            stopReason
        } else {
            StopReasonUtils.STOP_REASON_UNKNOWN
        }

    private fun executeBackgroundTask() {
        // Convert payload to the format expected by Pigeon (Map<String?, Object?>)
        val pigeonPayload = payload.mapKeys { it.key as String? }.mapValues { it.value as Object? }

        val localDartTask = dartTask

        if (localDartTask == null) {
            val exception = IllegalStateException("Dart task is null")
            WorkmanagerDebug.onExceptionEncountered(applicationContext, null, exception)

            stopEngine(Result.failure(), exception.message)
            return
        }

        flutterApi.executeTask(localDartTask, pigeonPayload) { result ->
            when {
                result.isSuccess -> {
                    val wasSuccessful = result.getOrNull() ?: false
                    stopEngine(if (wasSuccessful) Result.success() else Result.retry())
                }
                result.isFailure -> {
                    val exception = result.exceptionOrNull()
                    // Don't call onExceptionEncountered for Dart task failures
                    // These are handled as normal failures via onTaskStatusUpdate
                    stopEngine(Result.failure(), exception?.message)
                }
            }
        }
    }
}
