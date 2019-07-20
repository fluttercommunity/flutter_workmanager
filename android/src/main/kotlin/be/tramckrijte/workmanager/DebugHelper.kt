package be.tramckrijte.workmanager

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.ListenableWorker
import io.flutter.view.FlutterCallbackInformation

object DebugHelper {
    private const val debugChannelId = "WorkmanagerDebugChannelId"
    private const val debugChannelName = "A helper channel to debug your background tasks."

    fun postTaskCompleteNotification(ctx: Context, title: String, valueToReturn: String, result: ListenableWorker.Result) {
        postNotification(ctx, "$title ${System.currentTimeMillis()}", "${result.javaClass.simpleName}: $valueToReturn")
    }

    fun postTaskStarting(ctx: Context, echoValue: String, callbackHandle: Long, callbackInfo: FlutterCallbackInformation?, dartBundlePath: String) {
        postNotification(ctx, echoValue, "" +
                "callbackHandle: $callbackHandle;\n" +
                "callBackName: ${callbackInfo?.callbackName};\n" +
                "callbackClassName: ${callbackInfo?.callbackClassName};\n" +
                "callbackLibraryPath: ${callbackInfo?.callbackLibraryPath};\n" +
                "dartBundlePath: $dartBundlePath;"
        )
    }

    private fun postNotification(ctx: Context, title: String, contentText: String) {
        (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).apply {
            createNotificationChannel()

            notify(
                    System.currentTimeMillis().toInt(),
                    NotificationCompat.Builder(ctx, debugChannelId)
                            .setContentTitle(title)
                            .setContentText(contentText)
                            .setStyle(
                                    NotificationCompat.BigTextStyle()
                                            .bigText(contentText)
                            )
                            .setSmallIcon(R.drawable.notify_panel_notification_icon_bg)
                            .build()
            )
        }
    }

    private fun NotificationManager.createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            createNotificationChannel(NotificationChannel(debugChannelId, debugChannelName, NotificationManager.IMPORTANCE_DEFAULT))
        }
    }
}