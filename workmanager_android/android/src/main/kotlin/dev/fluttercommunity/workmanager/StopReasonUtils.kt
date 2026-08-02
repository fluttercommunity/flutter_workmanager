package dev.fluttercommunity.workmanager

import dev.fluttercommunity.workmanager.pigeon.TaskStatus

/**
 * WorkManager [StopReason](https://developer.android.com/reference/androidx/work/StopReason)
 * constants and helpers.
 *
 * WorkManager only populates the actual stop reason on Android 12 (API 31)
 * and newer; below that [STOP_REASON_UNKNOWN] is reported.
 */
object StopReasonUtils {
    const val STOP_REASON_UNKNOWN = 0
    const val STOP_REASON_CANCELLED_BY_APP = 3
    const val STOP_REASON_SYSTEM_IGNORED_CANCELLED_BY_APP = 4

    /**
     * Maps a stop reason to the debug [TaskStatus] reported by the plugin.
     *
     * App-initiated cancellations surface as [TaskStatus.CANCELLED]; every
     * other stop keeps the previous [TaskStatus.FAILED] behavior.
     */
    fun toTaskStatus(stopReason: Int): TaskStatus =
        when (stopReason) {
            STOP_REASON_CANCELLED_BY_APP,
            STOP_REASON_SYSTEM_IGNORED_CANCELLED_BY_APP,
            -> TaskStatus.CANCELLED
            else -> TaskStatus.FAILED
        }
}
