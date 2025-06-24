package dev.fluttercommunity.workmanager

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * A Flutter plugin that provides a foreground channel for workmanager operations.
 *
 * This implementation uses Flutter's v2 embedding API.
 */
class WorkmanagerPlugin : FlutterPlugin {
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
        methodChannel = MethodChannel(messenger, "dev.fluttercommunity.workmanager/foreground_channel_work_manager")
        methodChannel?.setMethodCallHandler(workmanagerCallHandler)
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
