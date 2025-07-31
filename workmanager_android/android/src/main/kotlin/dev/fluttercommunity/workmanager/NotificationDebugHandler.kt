package dev.fluttercommunity.workmanager

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import dev.fluttercommunity.workmanager.pigeon.TaskStatus
import java.text.DateFormat
import java.util.Date
import java.util.concurrent.TimeUnit.MILLISECONDS
import kotlin.random.Random

/**
 * A debug handler that shows notifications for task events.
 * Note: You need to ensure your app has notification permissions.
 *
 * @param channelId Custom notification channel ID (defaults to "WorkmanagerDebugChannelId")
 * @param channelName Custom notification channel name (defaults to "Workmanager Debug")
 * @param groupKey Custom notification group key for grouping notifications (optional)
 */
class NotificationDebugHandler(
    private val channelId: String = "WorkmanagerDebugChannelId",
    private val channelName: String = "Workmanager Debug",
    private val groupKey: String? = null,
) : WorkmanagerDebug() {
    private val isUsingDefaultChannel = channelId == "WorkmanagerDebugChannelId"

    companion object {
        private val debugDateFormatter =
            DateFormat.getTimeInstance(DateFormat.SHORT)
    }

    private val startEmoji = "▶️"
    private val retryEmoji = "🔄"
    private val successEmoji = "✅"
    private val failureEmoji = "❌"
    private val stopEmoji = "⏹️"
    private val currentTime get() = debugDateFormatter.format(Date())

    override fun onTaskStatusUpdate(
        context: Context,
        taskInfo: TaskDebugInfo,
        status: TaskStatus,
        result: TaskResult?,
    ) {
        val notificationId = Random.nextInt()
        val (emoji, title, content) =
            when (status) {
                TaskStatus.SCHEDULED ->
                    Triple(
                        "📅",
                        "Scheduled",
                        taskInfo.taskName,
                    )
                TaskStatus.STARTED ->
                    Triple(
                        startEmoji,
                        "Started",
                        taskInfo.taskName,
                    )
                TaskStatus.RETRYING ->
                    Triple(
                        retryEmoji,
                        "Retrying",
                        taskInfo.taskName,
                    )
                TaskStatus.RESCHEDULED ->
                    Triple(
                        retryEmoji,
                        "Rescheduled",
                        taskInfo.taskName,
                    )
                TaskStatus.COMPLETED -> {
                    val success = result?.success ?: false
                    val duration = MILLISECONDS.toSeconds(result?.duration ?: 0)
                    Triple(
                        if (success) successEmoji else failureEmoji,
                        if (success) "Success ${duration}s" else "Failed ${duration}s",
                        taskInfo.taskName,
                    )
                }
                TaskStatus.FAILED -> {
                    val duration = MILLISECONDS.toSeconds(result?.duration ?: 0)
                    Triple(
                        failureEmoji,
                        "Failed ${duration}s",
                        "${taskInfo.taskName}\n${result?.error ?: "Unknown"}",
                    )
                }
                TaskStatus.CANCELLED ->
                    Triple(
                        stopEmoji,
                        "Cancelled",
                        taskInfo.taskName,
                    )
            }

        postNotification(
            context,
            notificationId,
            "$emoji $title",
            content,
        )
    }

    override fun onExceptionEncountered(
        context: Context,
        taskInfo: TaskDebugInfo?,
        exception: Throwable,
    ) {
        val notificationId = Random.nextInt()
        val taskName = taskInfo?.taskName ?: "unknown"
        postNotification(
            context,
            notificationId,
            "$failureEmoji Exception",
            "$taskName\n${exception.message}",
        )
    }

    private fun postNotification(
        context: Context,
        notificationId: Int,
        title: String,
        contentText: String,
    ) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Only create notification channel if using default parameters
        if (isUsingDefaultChannel) {
            createNotificationChannel(notificationManager)
        }

        val notificationBuilder =
            NotificationCompat
                .Builder(context, channelId)
                .setContentTitle(title)
                .setContentText(contentText)
                .setStyle(
                    NotificationCompat
                        .BigTextStyle()
                        .bigText(contentText),
                ).setSmallIcon(android.R.drawable.stat_notify_sync)
                .setPriority(NotificationCompat.PRIORITY_LOW)

        // Add group key if specified
        groupKey?.let {
            notificationBuilder.setGroup(it)
        }

        val notification = notificationBuilder.build()

        notificationManager.notify(notificationId, notification)
    }

    private fun createNotificationChannel(notificationManager: NotificationManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel =
                NotificationChannel(
                    channelId,
                    channelName,
                    NotificationManager.IMPORTANCE_LOW,
                )
            notificationManager.createNotificationChannel(channel)
        }
    }
}
