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

        /**
         * How long the Dart engine may take to acknowledge the background
         * channel initialization after the worker started. A cold engine
         * start takes well under a second on release builds and a few seconds
         * on debug builds, so this is generous; its purpose is to turn a dead
         * Dart engine (failed isolate start, lost acknowledgement) into a
         * visible worker failure instead of a task stuck in the RUNNING state
         * forever (see #732).
         */
        const val DART_INITIALIZATION_TIMEOUT_MILLIS = 30_000L
    }

    private val payload
        get() = decodePayload(workerParams.inputData.keyValueMap)

    private val dartTask
        get() = workerParams.inputData.getString(DART_TASK_KEY)

    /**
     * The unique name the task was registered with, persisted in the worker's
     * [androidx.work.Data] at enqueue time. `null` only for tasks that were
     * enqueued before the unique name was persisted (older plugin versions).
     */
    val uniqueName: String?
        get() = workerParams.inputData.getString(UNIQUE_NAME_KEY)

    private val runAttemptCount = workerParams.runAttemptCount
    private val randomThreadIdentifier = SecureRandom().nextInt()

    /**
     * All interaction with the Flutter engine (channel sends included) must
     * happen on the main thread: engine methods are annotated `@UiThread` and
     * throw on any other thread. WorkManager may invoke [onStopped] from one
     * of its executor threads, so this handler is used to hop back to the
     * main looper.
     */
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var engine: FlutterEngine? = null

    private var initializationWatchdog: DartInitializationWatchdog? = null

    /**
     * The plugin instance attached to this worker's engine. The Dart task
     * runs on that engine, so its `reportProgress` calls arrive at this
     * plugin; binding the worker lets the plugin route them to us.
     */
    private var boundPlugin: WorkmanagerPlugin? = null

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
            engine?.let { engine ->
                // Bind this worker to the plugin instance attached to this
                // worker's engine, so progress reported from the Dart task
                // can be routed back to this worker.
                (engine.plugins.get(WorkmanagerPlugin::class.java) as? WorkmanagerPlugin)?.let { plugin ->
                    boundPlugin = plugin
                    plugin.bindWorker(this)
                }
            }
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

                // The worker's result future is only resolved once the Dart
                // side acknowledges the initialized background channel. If
                // the engine fails to start the Dart isolate, or the
                // acknowledgement is lost, the worker would otherwise stay
                // in the RUNNING state forever (see #732). Arm a watchdog
                // that fails the worker when the acknowledgement does not
                // arrive in time; it is disarmed on acknowledgement and on
                // stop.
                val watchdog =
                    DartInitializationWatchdog(
                        handler = mainHandler,
                        timeoutMillis = DART_INITIALIZATION_TIMEOUT_MILLIS,
                    ) {
                        if (!isStopped) {
                            stopEngine(
                                Result.failure(),
                                "Dart engine did not initialize the background channel " +
                                    "within $DART_INITIALIZATION_TIMEOUT_MILLIS ms",
                            )
                        }
                    }
                initializationWatchdog = watchdog
                watchdog.arm()

                // Initialize the background channel
                flutterApi.backgroundChannelInitialized {
                    // Channel is initialized, now execute the task
                    watchdog.disarm()
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

        // WorkManager invokes onStopped() from one of its executor threads
        // (e.g. "WM.task-N"), and the Flutter engine only allows @UiThread
        // methods (channel sends included) on the main thread — calling the
        // Pigeon API directly here throws IllegalStateException on modern
        // engines (see #732). Notify the Dart callback that WorkManager
        // stopped the worker (cancelled, timed out, preempted, ...) so it can
        // persist state or release resources before the engine is torn down;
        // onStopped() itself returns immediately.
        mainHandler.post {
            initializationWatchdog?.disarm()

            if (localDartTask != null && ::flutterApi.isInitialized && engine != null) {
                try {
                    flutterApi.onTaskStopped(localDartTask, stopReason.toLong()) {
                        stopEngine(null, stopReason = stopReason)
                    }
                    return@post
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
    }

    /**
     * Persists [progress] for this task and makes it available to the app.
     *
     * Called by the plugin when the Dart task handler reports progress on
     * this worker's engine. The progress is stored through WorkManager's
     * `setProgressAsync` (so it is queryable via [androidx.work.WorkInfo])
     * and picked up by [ProgressUpdateCoordinator], which forwards it to the
     * app.
     */
    fun reportProgress(progress: Map<String?, Any?>?) {
        val localUniqueName = uniqueName
        if (localUniqueName == null) {
            // Task was enqueued before the unique name was persisted in the
            // worker data; there is no way to key the progress update.
            WorkmanagerDebug.onExceptionEncountered(
                applicationContext,
                TaskDebugInfo(taskName = "unknown", startTime = startTime),
                IllegalStateException("Cannot report progress for a task without a unique name"),
            )
            return
        }

        setProgressAsync(encodeProgressData(progress))
        ProgressUpdateCoordinator.onProgressReported(applicationContext, localUniqueName)
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

        // Unbind from the plugin before the engine is torn down, so progress
        // reported after the task finished is not routed to a dead worker.
        boundPlugin?.unbindWorker(this)
        boundPlugin = null

        // Teardown is idempotent: engine is cleared synchronously (stopEngine
        // may be invoked from the watchdog, the task result callback and the
        // stop path) and destroyed on the main thread.
        val engineToDestroy = engine
        engine = null
        if (engineToDestroy != null) {
            mainHandler.post {
                engineToDestroy.destroy()
            }
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
