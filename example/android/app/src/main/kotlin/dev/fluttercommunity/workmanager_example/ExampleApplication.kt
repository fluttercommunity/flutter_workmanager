package dev.fluttercommunity.workmanager_example

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import dev.fluttercommunity.workmanager.LoggingDebugHandler
import dev.fluttercommunity.workmanager.NotificationDebugHandler
import dev.fluttercommunity.workmanager.WorkmanagerDebug
import io.flutter.app.FlutterApplication

class ExampleApplication : FlutterApplication() {

    override fun onCreate() {
        super.onCreate()

        // Create custom notification channel for debug notifications
        val debugChannelId = "workmanager_debug"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                debugChannelId,
                "Workmanager Example Debug",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Debug notifications for background tasks in example app"
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }

        // EXAMPLE: Enable debug handlers for background tasks
        // Choose one of the following options:
        
        // Option 1: Custom notification handler using our custom channel
        WorkmanagerDebug.setCurrent(NotificationDebugHandler(
            channelId = debugChannelId,
            channelName = "Workmanager Example Debug", 
            groupKey = "workmanager_example_group"
        ))
        
        // Option 2: Default notification handler (creates and uses default channel)
        // WorkmanagerDebug.setCurrent(NotificationDebugHandler())
        
        // Option 3: Logging-based debug handler (writes to system log)
        // WorkmanagerDebug.setCurrent(LoggingDebugHandler())
        
        // Note: For Android 13+, the app needs to request POST_NOTIFICATIONS permission
        // at runtime from the Flutter side or in the first activity
    }
}