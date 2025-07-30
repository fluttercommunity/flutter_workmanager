package dev.fluttercommunity.workmanager

import android.content.Context
import android.util.Log

/**
 * A debug handler that outputs debug information to Android's Log system.
 * Use this for development to see task execution in the console.
 */
class LoggingDebugHandler : WorkmanagerDebugHandler {
    companion object {
        private const val TAG = "WorkmanagerDebug"
    }

    override fun onTaskStarting(context: Context, taskInfo: TaskDebugInfo) {
        Log.d(TAG, "Task starting: ${taskInfo.taskName}, callbackHandle: ${taskInfo.callbackHandle}")
    }

    override fun onTaskCompleted(context: Context, taskInfo: TaskDebugInfo, result: TaskResult) {
        val status = if (result.success) "SUCCESS" else "FAILURE"
        Log.d(TAG, "Task completed: ${taskInfo.taskName}, result: $status, duration: ${result.duration}ms")
        if (result.error != null) {
            Log.e(TAG, "Task error: ${result.error}")
        }
    }
}