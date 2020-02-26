package be.tramckrijte.workmanager_example

import be.tramckrijte.workmanager.WorkmanagerPlugin
import io.flutter.app.FlutterApplication
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugins.GeneratedPluginRegistrant

@Deprecated(message = "Not used, but here to show you how you can use the plugin using the old v1 embedding method.")
class EmbeddingV1Application : FlutterApplication(), PluginRegistry.PluginRegistrantCallback {
    override fun registerWith(registry: PluginRegistry) {
        // The line below this would be uncommented
        // GeneratedPluginRegistrant.registerWith(registry)
    }

    override fun onCreate() {
        super.onCreate()
        WorkmanagerPlugin.setPluginRegistrantCallback(this)
    }
}
