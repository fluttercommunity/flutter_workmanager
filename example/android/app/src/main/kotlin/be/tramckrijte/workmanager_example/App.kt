package be.tramckrijte.workmanager_example

import  be.tramckrijte.workmanager.WorkmanagerPlugin
import io.flutter.app.FlutterApplication
import io.flutter.embedding.android.FlutterEngineConfigurator
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class App : FlutterApplication(), FlutterEngineConfigurator {
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {

    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }

    override fun onCreate() {
        super.onCreate()
        WorkmanagerPlugin.setPluginRegistrantCallback(this)
    }
}