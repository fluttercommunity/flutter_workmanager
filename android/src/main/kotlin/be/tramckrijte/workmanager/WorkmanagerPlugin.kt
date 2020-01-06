package be.tramckrijte.workmanager

import io.flutter.embedding.android.FlutterEngineConfigurator
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class WorkmanagerPlugin : MethodCallHandler, FlutterPlugin {

    private lateinit var workmanagerCallHandler: WorkmanagerCallHandler

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val channel = MethodChannel(binding.binaryMessenger, "be.tramckrijte.workmanager/foreground_channel_work_manager")
        channel.setMethodCallHandler(WorkmanagerPlugin().apply { workmanagerCallHandler = WorkmanagerCallHandler(binding.applicationContext) })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}

    companion object {
        lateinit var engineConfigurator: FlutterEngineConfigurator

        @JvmStatic
        fun setPluginRegistrantCallback(engineConfigurator: FlutterEngineConfigurator) {
            WorkmanagerPlugin.engineConfigurator = engineConfigurator
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) = workmanagerCallHandler.handle(call, result)
}
