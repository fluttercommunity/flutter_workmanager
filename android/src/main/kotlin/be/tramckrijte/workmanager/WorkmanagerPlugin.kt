package be.tramckrijte.workmanager

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.PluginRegistry.Registrar

class WorkmanagerPlugin(private val workmanagerCallHandler: WorkmanagerCallHandler) : MethodCallHandler {

    companion object {
        //Currently unused; Not sure whether this is really needed
        lateinit var pluginRegistryCallback: PluginRegistry.PluginRegistrantCallback

        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "be.tramckrijte.workmanager/foreground_channel_work_manager")
            channel.setMethodCallHandler(WorkmanagerPlugin(WorkmanagerCallHandler(registrar.activeContext())))
        }

        fun setPluginRegistrantCallback(pluginRegistryCallback: PluginRegistry.PluginRegistrantCallback) {
            WorkmanagerPlugin.pluginRegistryCallback = pluginRegistryCallback
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) = workmanagerCallHandler.handle(call, result)
}
