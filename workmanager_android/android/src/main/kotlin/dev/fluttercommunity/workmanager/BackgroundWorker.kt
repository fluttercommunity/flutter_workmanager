package dev.fluttercommunity.workmanager

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.work.ListenableWorker
import androidx.work.WorkerParameters
import com.google.common.util.concurrent.ListenableFuture
import dev.fluttercommunity.workmanager.pigeon.WorkmanagerFlutterApi
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.view.FlutterCallbackInformation
import java.util.Random

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
        const val TAG = "BackgroundWorker"

        const val PAYLOAD_KEY = "dev.fluttercommunity.workmanager.INPUT_DATA"
        const val DART_TASK_KEY = "dev.fluttercommunity.workmanager.DART_TASK"

        private val flutterLoader = FlutterLoader()
    }

    private val payload
        get() =
            workerParams.inputData.keyValueMap
                .filter { it.key.startsWith("payload_") }
                .mapKeys { it.key.replace("payload_", "") }
                .mapValues {
                    when (it.value) {
                        is Array<*> -> (it.value as Array<*>).asList()
                        else -> it.value
                    }
                }

    private val dartTask
        get() = workerParams.inputData.getString(DART_TASK_KEY)!!

    private val randomThreadIdentifier = Random().nextInt()
    private var engine: FlutterEngine? = null

    private var startTime: Long = 0

    private var completer: CallbackToFutureAdapter.Completer<Result>? = null

    private var resolvableFuture =
        CallbackToFutureAdapter.getFuture { completer ->
            this.completer = completer
            null
        }

    override fun startWork(): ListenableFuture<Result> {
        startTime = System.currentTimeMillis()

        engine = FlutterEngine(applicationContext)

        if (!flutterLoader.initialized()) {
            flutterLoader.startInitialization(applicationContext)
        }

        flutterLoader.ensureInitializationCompleteAsync(
            applicationContext,
            null,
            Handler(Looper.getMainLooper()),
        ) {
            val callbackHandle = SharedPreferenceHelper.getCallbackHandle(applicationContext)
            val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)

            if (callbackInfo == null) {
                val exception = IllegalStateException("Failed to resolve Dart callback for handle $callbackHandle")
                Log.e(TAG, exception.message)
                WorkmanagerDebug.onExceptionEncountered(applicationContext, null, exception)
                completer?.set(Result.failure())
                return@ensureInitializationCompleteAsync
            }

            val dartBundlePath = flutterLoader.findAppBundlePath()

            val taskInfo = TaskDebugInfo(
                taskName = dartTask,
                inputData = payload,
                startTime = startTime,
                callbackHandle = callbackHandle,
                callbackInfo = callbackInfo?.callbackName,
            )
            
            WorkmanagerDebug.onTaskStatusUpdate(applicationContext, taskInfo, TaskStatus.STARTED)

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

        return resolvableFuture
    }

    override fun onStopped() {
        stopEngine(null)
    }

    private fun stopEngine(result: Result?) {
        val fetchDuration = System.currentTimeMillis() - startTime

        val taskInfo = TaskDebugInfo(
            taskName = dartTask,
            inputData = payload,
            startTime = startTime,
        )
        
        val taskResult = TaskResult(
            success = result is Result.Success,
            duration = fetchDuration,
            error = if (result is Result.Failure) "Task failed" else null,
        )
        
        val status = if (result is Result.Success) TaskStatus.COMPLETED else TaskStatus.FAILED
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

    private fun executeBackgroundTask() {
        // Convert payload to the format expected by Pigeon (Map<String?, Object?>)
        val pigeonPayload = payload.mapKeys { it.key as String? }.mapValues { it.value as Object? }

        flutterApi.executeTask(dartTask, pigeonPayload) { result ->
            when {
                result.isSuccess -> {
                    val wasSuccessful = result.getOrNull() ?: false
                    stopEngine(if (wasSuccessful) Result.success() else Result.retry())
                }
                result.isFailure -> {
                    val exception = result.exceptionOrNull()
                    Log.e(TAG, "Error executing task: ${exception?.message}")
                    if (exception != null) {
                        val taskInfo = TaskDebugInfo(
                            taskName = dartTask,
                            inputData = payload,
                            startTime = startTime
                        )
                        WorkmanagerDebug.onExceptionEncountered(applicationContext, taskInfo, exception)
                    }
                    stopEngine(Result.failure())
                }
            }
        }
    }
}
