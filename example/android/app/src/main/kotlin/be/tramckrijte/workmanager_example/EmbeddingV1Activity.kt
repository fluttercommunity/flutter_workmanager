package be.tramckrijte.workmanager_example

import android.os.Bundle
import io.flutter.app.FlutterActivity
import io.flutter.plugins.GeneratedPluginRegistrant

@Deprecated(message = "Not used, but here to show you how you can use the plugin using the old v1 embedding method.")
class EmbeddingV1Activity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The line below this would be uncommented
        // GeneratedPluginRegistrant.registerWith(this)
    }
}
