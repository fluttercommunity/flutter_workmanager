package dev.fluttercommunity.workmanager

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class WorkmanagerPlugin : FlutterPlugin, MethodCallHandler {
    private var methodChannel: MethodChannel? = null
    private var workmanagerCallHandler: WorkmanagerCallHandler? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        onAttachedToEngine(binding.applicationContext, binding.binaryMessenger)
    }

    private fun onAttachedToEngine(
        context: Context,
        messenger: BinaryMessenger,
    ) {
        workmanagerCallHandler = WorkmanagerCallHandler(context)
        methodChannel = MethodChannel(messenger, "be.tramckrijte.workmanager/foreground_channel_work_manager")
        methodChannel?.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        workmanagerCallHandler?.handle(call, result)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        onDetachedFromEngine()
    }

    private fun onDetachedFromEngine() {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        workmanagerCallHandler = null
    }
}