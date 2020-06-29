package be.tramckrijte.workmanager

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.concurrent.futures.ResolvableFuture
import androidx.work.ListenableWorker
import androidx.work.WorkerParameters
import com.google.common.util.concurrent.ListenableFuture
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.plugins.shim.ShimPluginRegistry
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import io.flutter.view.FlutterMain
import java.util.*

/***
 * A simple worker that will post your input back to your Flutter application.
 *
 * It will block the background thread until a value of either true or false is received back from Flutter code.
 *
 */
class BackgroundWorker(
    private val ctx: Context,
    private val workerParams: WorkerParameters
) : ListenableWorker(ctx, workerParams), MethodChannel.MethodCallHandler {

    private lateinit var backgroundChannel: MethodChannel

    companion object {
        const val PAYLOAD_KEY = "be.tramckrijte.workmanager.INPUT_DATA"
        const val DART_TASK_KEY = "be.tramckrijte.workmanager.DART_TASK"
        const val IS_IN_DEBUG_MODE_KEY = "be.tramckrijte.workmanager.IS_IN_DEBUG_MODE_KEY"

        const val BACKGROUND_CHANNEL_NAME = "be.tramckrijte.workmanager/background_channel_work_manager"
        const val BACKGROUND_CHANNEL_INITIALIZED = "backgroundChannelInitialized"
    }

    private val payload
        get() = workerParams.inputData.getString(PAYLOAD_KEY)

    private val dartTask
        get() = workerParams.inputData.getString(DART_TASK_KEY)!!

    private val isInDebug
        get() = workerParams.inputData.getBoolean(IS_IN_DEBUG_MODE_KEY, false)

    private val randomThreadIdentifier = Random().nextInt()
    private lateinit var engine: FlutterEngine

    private var destroying = false
    private var startTime: Long = 0
    private val resolvableFuture = ResolvableFuture.create<Result>()

    override fun startWork(): ListenableFuture<Result> {
        startTime = System.currentTimeMillis()

        engine = FlutterEngine(ctx)
        FlutterMain.ensureInitializationComplete(ctx, null)

        val callbackHandle = SharedPreferenceHelper.getCallbackHandle(ctx)
        val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)
        val dartBundlePath = FlutterMain.findAppBundlePath()

        if (isInDebug) {
            DebugHelper.postTaskStarting(
                ctx,
                randomThreadIdentifier,
                dartTask,
                payload,
                callbackHandle,
                callbackInfo,
                dartBundlePath
            )
        }

        //Backwards compatibility with v1. We register all the user's plugins.
        WorkmanagerPlugin.pluginRegistryCallback?.registerWith(ShimPluginRegistry(engine))
        engine.dartExecutor.executeDartCallback(DartExecutor.DartCallback(ctx.assets, dartBundlePath, callbackInfo))

        backgroundChannel = MethodChannel(engine.dartExecutor, BACKGROUND_CHANNEL_NAME)
        backgroundChannel.setMethodCallHandler(this@BackgroundWorker)

        return resolvableFuture
    }

    override fun onStopped() {
        stopEngine(null)
    }

    private fun stopEngine(result: Result?) {
        val fetchDuration = System.currentTimeMillis() - startTime

        if (isInDebug) {
            DebugHelper.postTaskCompleteNotification(
                ctx,
                randomThreadIdentifier,
                dartTask,
                payload,
                fetchDuration,
                result ?: Result.failure()
            )
        }

        // No result indicates we were signalled to stop by WorkManager.  The result is already
        // STOPPED, so no need to resolve another one.
        if (result != null) {
            resolvableFuture.set(result)
        }

        // If stopEngine is called from `onStopped`, it may not be from the main thread.
        Handler(Looper.getMainLooper()).post {
            if (!destroying) {
                if (this::engine.isInitialized)
                    engine.destroy()
                destroying = true
            }
        }
    }

    override fun onMethodCall(call: MethodCall, r: MethodChannel.Result) {
        when (call.method) {
            BACKGROUND_CHANNEL_INITIALIZED ->
                backgroundChannel.invokeMethod(
                    "onResultSend",
                    mapOf(DART_TASK_KEY to dartTask, PAYLOAD_KEY to payload),
                    object : MethodChannel.Result {
                        override fun notImplemented() {
                            stopEngine(Result.failure())
                        }

                        override fun error(p0: String?, p1: String?, p2: Any?) {
                            stopEngine(Result.failure())
                        }

                        override fun success(receivedResult: Any?) {
                            val wasSuccessFul = receivedResult?.let { it as Boolean? } == true
                            stopEngine(if (wasSuccessFul) Result.success() else Result.retry())
                        }
                    })
        }
    }
}
