package be.tramckrijte.workmanager

import android.content.Context
import io.flutter.embedding.android.FlutterEngineConfigurator
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

class WorkmanagerPlugin : MethodCallHandler, FlutterPlugin {

    private lateinit var workmanagerCallHandler: WorkmanagerCallHandler

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) =
            registerWorkManager(binding.binaryMessenger, binding.applicationContext)

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}

    companion object {
        var pluginRegistryCallback: PluginRegistry.PluginRegistrantCallback? = null

        @JvmStatic
        private fun registerWorkManager(messenger: BinaryMessenger, ctx: Context) {
            val channel = MethodChannel(messenger, "be.tramckrijte.workmanager/foreground_channel_work_manager")
            channel.setMethodCallHandler(WorkmanagerPlugin().apply { workmanagerCallHandler = WorkmanagerCallHandler(ctx) })
        }

        @JvmStatic
        fun registerWith(registrar: PluginRegistry.Registrar) =
                registerWorkManager(registrar.messenger(), registrar.activeContext())

        @Deprecated(message = "Use the Android v2 embedding method.")
        @JvmStatic
        fun setPluginRegistrantCallback(pluginRegistryCallback: PluginRegistry.PluginRegistrantCallback) {
            WorkmanagerPlugin.pluginRegistryCallback = pluginRegistryCallback
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) = workmanagerCallHandler.handle(call, result)
}
