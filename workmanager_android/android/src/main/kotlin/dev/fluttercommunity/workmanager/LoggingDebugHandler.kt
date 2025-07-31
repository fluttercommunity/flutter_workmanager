package dev.fluttercommunity.workmanager

import android.content.Context
import android.util.Log
import dev.fluttercommunity.workmanager.pigeon.TaskStatus

/**
 * A debug handler that outputs debug information to Android's Log system.
 */
class LoggingDebugHandler : WorkmanagerDebug() {
    companion object {
        private const val TAG = "WorkmanagerDebug"
    }

    override fun onTaskStatusUpdate(
        context: Context,
        taskInfo: TaskDebugInfo,
        status: TaskStatus,
        result: TaskResult?,
    ) {
        when (status) {
            TaskStatus.SCHEDULED -> Log.d(TAG, "Task scheduled: ${taskInfo.taskName}")
            TaskStatus.STARTED -> Log.d(TAG, "Task started: ${taskInfo.taskName}, callbackHandle: ${taskInfo.callbackHandle}")
            TaskStatus.COMPLETED -> {
                val success = result?.success ?: false
                val duration = result?.duration ?: 0
                Log.d(TAG, "Task completed: ${taskInfo.taskName}, success: $success, duration: ${duration}ms")
            }
            TaskStatus.FAILED -> {
                val error = result?.error ?: "Unknown error"
                Log.e(TAG, "Task failed: ${taskInfo.taskName}, error: $error")
            }
            TaskStatus.CANCELLED -> Log.w(TAG, "Task cancelled: ${taskInfo.taskName}")
            TaskStatus.RETRYING -> Log.w(TAG, "Task retrying: ${taskInfo.taskName}")
            TaskStatus.RESCHEDULED -> Log.w(TAG, "Task rescheduled: ${taskInfo.taskName}")
        }
    }

    override fun onExceptionEncountered(
        context: Context,
        taskInfo: TaskDebugInfo?,
        exception: Throwable,
    ) {
        val taskName = taskInfo?.taskName ?: "unknown"
        Log.e(TAG, "Exception in task: $taskName", exception)
    }
}
