package be.tramckrijte.workmanager

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.ListenableWorker
import io.flutter.view.FlutterCallbackInformation
import java.text.SimpleDateFormat
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.*

object DebugHelper {
    private const val debugChannelId = "WorkmanagerDebugChannelId"
    private const val debugChannelName = "A helper channel to debug your background tasks."
    private val debugDateFormatter = SimpleDateFormat("dd-MM-yyyy HH:mm:ss.ZZZZ")

    private val currentTime get() = debugDateFormatter.format(Date())

    fun postTaskCompleteNotification(ctx: Context, dartTask: String, result: ListenableWorker.Result) {
        postNotification(ctx, dartTask.hashCode(), currentTime, "Your work for $dartTask returned result: ${result.javaClass.simpleName}")
    }

    fun postTaskStarting(ctx: Context, dartTask: String, callbackHandle: Long, callbackInfo: FlutterCallbackInformation?, dartBundlePath: String?) {
        postNotification(ctx, dartTask.hashCode(), currentTime, "" +
                "Trying to start Dart/Flutter with following params: \n" +
                "dartTask: $dartTask;\n" +
                "callbackHandle: $callbackHandle;\n" +
                "callBackName: ${callbackInfo?.callbackName};\n" +
                "callbackClassName: ${callbackInfo?.callbackClassName};\n" +
                "callbackLibraryPath: ${callbackInfo?.callbackLibraryPath};\n" +
                "dartBundlePath: $dartBundlePath;"
        )
    }

    private fun postNotification(ctx: Context, messageId: Int, title: String, contentText: String) {
        (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).apply {
            createNotificationChannel()

            notify(
                    messageId,
                    NotificationCompat.Builder(ctx, debugChannelId)
                            .setContentTitle(title)
                            .setContentText(contentText)
                            .setStyle(
                                    NotificationCompat.BigTextStyle()
                                            .bigText(contentText)
                            )
                            .setSmallIcon(android.R.drawable.stat_notify_sync)
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