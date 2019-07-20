package be.tramckrijte.workmanager

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import io.flutter.view.FlutterMain
import io.flutter.view.FlutterNativeView
import io.flutter.view.FlutterRunArguments
import java.util.concurrent.CountDownLatch

/***
 * A simple worker that will post your input back to your Flutter application.
 *
 * It will block the background thread until a value of either true or false is received back from Flutter code.
 *
 */
class EchoingWorker(private val ctx: Context,
                    private val workerParams: WorkerParameters) : Worker(ctx, workerParams), MethodChannel.MethodCallHandler {

    private lateinit var backgroundChannel: MethodChannel

    companion object {
        const val VALUE_TO_ECHO_KEY = "be.tramckrijte.workmanager.VALUE_TO_ECHO_KEY"
        const val IS_IN_DEBUG_MODE = "be.tramckrijte.workmanager.IS_IN_DEBUG_MODE"

        const val BACKGROUND_CHANNEL_NAME = "be.tramckrijte.workmanager/background_channel_work_manager"
        const val BACKGROUND_CHANNEL_INITIALIZED = "backgroundChannelInitialized"
        const val ECHO_METHOD_NAME = "echoTaskRan"
    }

    private val echoValue
        get() = workerParams.inputData.getString(VALUE_TO_ECHO_KEY)

    private val latch = CountDownLatch(1)
    var result: Result = Result.retry()

    override fun doWork(): Result {
        Handler(Looper.getMainLooper()).post {
            FlutterMain.ensureInitializationComplete(ctx, null)
            //val appBundlePath = FlutterMain.findAppBundlePath(ctx)

            val callbackHandle = SharedPreferenceHelper.getCallbackHandle(ctx)
            val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)

            val backgroundFlutterView = FlutterNativeView(ctx, true)

            val args =
                    FlutterRunArguments()
                            .apply {
                                bundlePath = FlutterMain.findAppBundlePath(ctx)
                                entrypoint = callbackInfo.callbackName
                                libraryPath = callbackInfo.callbackLibraryPath
                            }

            backgroundFlutterView.runFromBundle(args)

            backgroundChannel = MethodChannel(backgroundFlutterView, BACKGROUND_CHANNEL_NAME)
            backgroundChannel.setMethodCallHandler(this)
        }

        latch.await()

        if (workerParams.inputData.getBoolean(IS_IN_DEBUG_MODE, false)) {
            DebugHelper.postTaskNotification(ctx, javaClass.simpleName, "$echoValue", result)
        }

        return result
    }

    override fun onMethodCall(call: MethodCall, r: MethodChannel.Result) {
        when (call.method) {
            BACKGROUND_CHANNEL_INITIALIZED ->
                backgroundChannel.invokeMethod(
                        ECHO_METHOD_NAME,
                        echoValue,
                        object : MethodChannel.Result {
                            override fun notImplemented() {
                                latch.countDown()
                            }

                            override fun error(p0: String?, p1: String?, p2: Any?) {
                                latch.countDown()
                            }

                            override fun success(p0: Any?) {
                                result = Result.success()
                                latch.countDown()
                            }
                        })
        }
    }
}