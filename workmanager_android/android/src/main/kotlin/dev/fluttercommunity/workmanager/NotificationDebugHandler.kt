package dev.fluttercommunity.workmanager

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.ListenableWorker
import java.text.DateFormat
import java.util.Date
import java.util.concurrent.TimeUnit.MILLISECONDS
import kotlin.random.Random

/**
 * A debug handler that shows notifications for task events.
 * Use this to see task execution as notifications on the device.
 * 
 * Note: You need to ensure your app has notification permissions.
 */
class NotificationDebugHandler : WorkmanagerDebugHandler {
    companion object {
        private const val DEBUG_CHANNEL_ID = "WorkmanagerDebugChannelId"
        private const val DEBUG_CHANNEL_NAME = "Workmanager Debug Notifications"
        private val debugDateFormatter =
            DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.MEDIUM)
    }

    private val workEmoji get() = listOf("👷‍♀️", "👷‍♂️").random()
    private val successEmoji = "🎉"
    private val failureEmoji = "🔥"
    private val currentTime get() = debugDateFormatter.format(Date())

    override fun onTaskStarting(context: Context, taskInfo: TaskDebugInfo) {
        val notificationId = Random.nextInt()
        postNotification(
            context,
            notificationId,
            "$workEmoji $currentTime",
            """
            • Task Starting: ${taskInfo.taskName}
            • Input Data: ${taskInfo.inputData ?: "none"}
            • Callback Handle: ${taskInfo.callbackHandle}
            """.trimIndent()
        )
    }

    override fun onTaskCompleted(context: Context, taskInfo: TaskDebugInfo, result: TaskResult) {
        val notificationId = Random.nextInt()
        val emoji = if (result.success) successEmoji else failureEmoji
        val status = if (result.success) "SUCCESS" else "FAILURE"
        val duration = MILLISECONDS.toSeconds(result.duration)
        
        postNotification(
            context,
            notificationId,
            "$workEmoji $currentTime",
            """
            • Result: $emoji $status
            • Task: ${taskInfo.taskName}
            • Input Data: ${taskInfo.inputData ?: "none"}
            • Duration: ${duration}s
            ${if (result.error != null) "• Error: ${result.error}" else ""}
            """.trimIndent()
        )
    }

    private fun postNotification(
        context: Context,
        notificationId: Int,
        title: String,
        contentText: String,
    ) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        createNotificationChannel(notificationManager)
        
        val notification = NotificationCompat
            .Builder(context, DEBUG_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(contentText)
            .setStyle(
                NotificationCompat
                    .BigTextStyle()
                    .bigText(contentText)
            )
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
            
        notificationManager.notify(notificationId, notification)
    }

    private fun createNotificationChannel(notificationManager: NotificationManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                DEBUG_CHANNEL_ID,
                DEBUG_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            )
            notificationManager.createNotificationChannel(channel)
        }
    }
}