package be.tramckrijte.workmanager

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat

object DebugHelper {
    private const val debugChannelId = "WorkmanagerDebugChannelId"
    private const val debugChannelName = "A helper channel to debug your background tasks."

    fun postTaskNotification(ctx: Context, title: String, valueToReturn: String) {
        (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                createNotificationChannel(NotificationChannel(debugChannelId, debugChannelName, NotificationManager.IMPORTANCE_DEFAULT))
            }

            notify(
                    System.currentTimeMillis().toInt(),
                    NotificationCompat.Builder(ctx, debugChannelId)
                            .setContentTitle("$title ${System.currentTimeMillis()}")
                            .setContentText(valueToReturn)
                            .setSmallIcon(R.drawable.notify_panel_notification_icon_bg)
                            .build()
            )
        }
    }
}