package be.tramckrijte.workmanager

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.ListenableWorker
import io.flutter.view.FlutterCallbackInformation
import java.text.DateFormat
import java.util.*
import java.util.concurrent.TimeUnit.MILLISECONDS

object ThumbnailGenerator {
    fun mapResultToEmoji(result: ListenableWorker.Result): String =
            when (result) {
                is ListenableWorker.Result.Success -> "\uD83C\uDF89"
                else -> "\uD83D\uDD25"
            }

    val workEmoji get() = listOf("\uD83D\uDC77\u200D♀️", "\uD83D\uDC77\u200D♂️").random()
}

object DebugHelper {
    private const val debugChannelId = "WorkmanagerDebugChannelId"
    private const val debugChannelName = "A helper channel to debug your background tasks."
    private val debugDateFormatter = DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.MEDIUM)

    private val currentTime get() = debugDateFormatter.format(Date())

    private fun mapMillisToSeconds(milliseconds: Long) = "${MILLISECONDS.toSeconds(milliseconds)} seconds."

    fun postTaskCompleteNotification(ctx: Context,
                                     threadIdentifier: Int,
                                     dartTask: String,
                                     payload: String? = null,
                                     fetchDuration: Long,
                                     result: ListenableWorker.Result) {
        postNotification(
                ctx,
                threadIdentifier,
                "${ThumbnailGenerator.workEmoji} $currentTime",
                """
                    • Result: ${ThumbnailGenerator.mapResultToEmoji(result)} ${result.javaClass.simpleName}
                    • dartTask: $dartTask
                    • inputData: ${payload ?: "not found"}
                    • Elapsed time: ${mapMillisToSeconds(fetchDuration)}
                """.trimIndent()
        )
    }

    fun postTaskStarting(ctx: Context,
                         threadIdentifier: Int,
                         dartTask: String,
                         payload: String? = null,
                         callbackHandle: Long,
                         callbackInfo: FlutterCallbackInformation?,
                         dartBundlePath: String?) {
        postNotification(ctx,
                threadIdentifier,
                "${ThumbnailGenerator.workEmoji} $currentTime",
                """
                • dartTask: $dartTask
                • inputData: ${payload ?: "not found"}
                • callbackHandle: $callbackHandle 
                • callBackName: ${callbackInfo?.callbackName ?: "not found"}
                • callbackClassName: ${callbackInfo?.callbackClassName ?: "not found"}
                • callbackLibraryPath: ${callbackInfo?.callbackLibraryPath ?: "not found"}
                • dartBundlePath: $dartBundlePath"
                """.trimIndent()

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