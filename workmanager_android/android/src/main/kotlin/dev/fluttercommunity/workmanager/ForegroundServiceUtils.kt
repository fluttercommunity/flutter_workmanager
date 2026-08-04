package dev.fluttercommunity.workmanager

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.ForegroundInfo
import dev.fluttercommunity.workmanager.pigeon.ForegroundServiceConfig
import dev.fluttercommunity.workmanager.pigeon.ForegroundServiceType

// Defaults mirroring the ones resolved in the Dart platform implementation.
// They keep the native side robust for work requests enqueued before a value
// was resolved (e.g. legacy persisted jobs or direct WorkManager enqueues).
private const val DEFAULT_NOTIFICATION_CHANNEL_ID = "workmanager_foreground_tasks"
private const val DEFAULT_NOTIFICATION_CHANNEL_NAME = "Long-running tasks"
private const val DEFAULT_NOTIFICATION_TITLE = "Task in progress"
private const val DEFAULT_NOTIFICATION_TEXT = "Your task is still running"
private const val DEFAULT_NOTIFICATION_ID = 0

/**
 * Builds the [ForegroundInfo] used to promote a worker to a foreground service.
 *
 * On Android 14+ (target SDK 34+) the foreground service type must be declared
 * in the manifest (see the plugin's AndroidManifest.xml) and passed to
 * `startForeground`; below Android 14 the type parameter is not validated, so
 * it is omitted entirely.
 */
fun createForegroundInfo(
    context: Context,
    config: ForegroundServiceConfig,
): ForegroundInfo {
    createNotificationChannel(context, config)

    val notification =
        NotificationCompat
            .Builder(context, config.notificationChannelId ?: DEFAULT_NOTIFICATION_CHANNEL_ID)
            .setContentTitle(config.notificationTitle ?: DEFAULT_NOTIFICATION_TITLE)
            .setContentText(config.notificationText ?: DEFAULT_NOTIFICATION_TEXT)
            .setSmallIcon(resolveNotificationIcon(context))
            .setOngoing(true)
            .build()

    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
        ForegroundInfo(
            config.notificationId?.toInt() ?: DEFAULT_NOTIFICATION_ID,
            notification,
            resolveForegroundServiceType(context, config),
        )
    } else {
        ForegroundInfo(config.notificationId?.toInt() ?: DEFAULT_NOTIFICATION_ID, notification)
    }
}

/**
 * Creates the notification channel used by the foreground service notification.
 * Notification channels only exist on Android 8.0+ (API 26).
 */
private fun createNotificationChannel(
    context: Context,
    config: ForegroundServiceConfig,
) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
        return
    }
    val channel =
        NotificationChannel(
            config.notificationChannelId ?: DEFAULT_NOTIFICATION_CHANNEL_ID,
            config.notificationChannelName ?: DEFAULT_NOTIFICATION_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW,
        )
    context
        .getSystemService(NotificationManager::class.java)
        .createNotificationChannel(channel)
}

/**
 * Fails loudly when a foreground-service feature is used without the manifest
 * declaration it needs (see issue #725). Normal permissions are granted at
 * install when declared, so a missing declaration surfaces as DENIED here.
 */
internal fun requireForegroundServicePermission(
    context: Context,
    permission: String,
    featureDescription: String,
    fixHint: String,
) {
    val granted =
        context.packageManager.checkPermission(permission, context.packageName) ==
            PackageManager.PERMISSION_GRANTED
    if (!granted) {
        throw IllegalStateException(
            "workmanager_android: $featureDescription requires the '$permission' permission " +
                "in the merged manifest, but it is missing. $fixHint",
        )
    }
}

private fun resolveForegroundServiceType(
    context: Context,
    config: ForegroundServiceConfig,
): Int =
    when (config.foregroundServiceType) {
        ForegroundServiceType.SHORT_SERVICE ->
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE
        else -> {
            // dataSync is opt-in (see README, issue #725): the manifest only
            // declares FOREGROUND_SERVICE_DATA_SYNC when the app sets
            // workmanager.enableDataSyncForegroundService=true. Fail loudly
            // here instead of a cryptic SecurityException on Android 14+.
            requireForegroundServicePermission(
                context,
                android.Manifest.permission.FOREGROUND_SERVICE_DATA_SYNC,
                "foregroundServiceType=dataSync",
                "Add 'workmanager.enableDataSyncForegroundService=true' to your " +
                    "gradle.properties (see the workmanager_android README, issue #725).",
            )
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        }
    }

/**
 * Uses the application icon for the notification when available, falling back
 * to a generic system icon otherwise. The small icon must be a white silhouette
 * for best results; apps can provide their own drawable by overriding the
 * application icon.
 */
private fun resolveNotificationIcon(context: Context): Int {
    val applicationIcon = context.applicationInfo.icon
    return if (applicationIcon != 0) applicationIcon else android.R.drawable.ic_dialog_info
}
