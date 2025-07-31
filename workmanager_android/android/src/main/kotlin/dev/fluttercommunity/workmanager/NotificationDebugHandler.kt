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
 */
class NotificationDebugHandler : WorkmanagerDebug() {
    companion object {
        private const val DEBUG_CHANNEL_ID = "WorkmanagerDebugChannelId"
        private const val DEBUG_CHANNEL_NAME = "Workmanager Debug Notifications"
        private val debugDateFormatter =
            DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.MEDIUM)
    }

    private val workEmoji get() = listOf("👷‍♀️", "👷‍♂️").random()
    private val successEmoji = "🎉"
    private val failureEmoji = "🔥"
    private val warningEmoji = "⚠️"
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
                        "Task Scheduled",
                        "• Task: ${taskInfo.taskName}\n• Input Data: ${taskInfo.inputData ?: "none"}",
                    )
                TaskStatus.STARTED ->
                    Triple(
                        workEmoji,
                        "Task Starting",
                        "• Task: ${taskInfo.taskName}\n• Callback Handle: ${taskInfo.callbackHandle}",
                    )
                TaskStatus.COMPLETED -> {
                    val success = result?.success ?: false
                    val duration = MILLISECONDS.toSeconds(result?.duration ?: 0)
                    Triple(
                        if (success) successEmoji else failureEmoji,
                        if (success) "Task Completed" else "Task Failed",
                        "• Task: ${taskInfo.taskName}\n• Duration: ${duration}s${if (result?.error != null) "\n• Error: ${result.error}" else ""}",
                    )
                }
                TaskStatus.FAILED ->
                    Triple(
                        failureEmoji,
                        "Task Failed",
                        "• Task: ${taskInfo.taskName}\n• Error: ${result?.error ?: "Unknown error"}",
                    )
                TaskStatus.CANCELLED ->
                    Triple(
                        warningEmoji,
                        "Task Cancelled",
                        "• Task: ${taskInfo.taskName}",
                    )
                TaskStatus.RETRYING ->
                    Triple(
                        "🔄",
                        "Task Retrying",
                        "• Task: ${taskInfo.taskName}",
                    )
            }

        postNotification(
            context,
            notificationId,
            "$emoji $currentTime",
            "$title\n$content",
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
            "$failureEmoji $currentTime",
            "Exception in Task\n• Task: $taskName\n• Error: ${exception.message}",
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

        val notification =
            NotificationCompat
                .Builder(context, DEBUG_CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(contentText)
                .setStyle(
                    NotificationCompat
                        .BigTextStyle()
                        .bigText(contentText),
                ).setSmallIcon(android.R.drawable.stat_notify_sync)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()

        notificationManager.notify(notificationId, notification)
    }

    private fun createNotificationChannel(notificationManager: NotificationManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel =
                NotificationChannel(
                    DEBUG_CHANNEL_ID,
                    DEBUG_CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_LOW,
                )
            notificationManager.createNotificationChannel(channel)
        }
    }
}
