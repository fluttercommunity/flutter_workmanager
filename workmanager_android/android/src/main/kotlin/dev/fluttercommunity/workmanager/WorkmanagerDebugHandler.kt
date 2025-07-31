package dev.fluttercommunity.workmanager

import android.content.Context
import dev.fluttercommunity.workmanager.pigeon.TaskStatus

/**
 * Information about a task for debugging purposes.
 */
data class TaskDebugInfo(
    val taskName: String,
    val uniqueName: String? = null,
    val inputData: Map<String, Any?>? = null,
    val startTime: Long,
    val callbackHandle: Long? = null,
    val callbackInfo: String? = null,
)

/**
 * Result information for a completed task.
 */
data class TaskResult(
    val success: Boolean,
    val duration: Long,
    val error: String? = null,
)

/**
 * Abstract debug handler for Workmanager events.
 * Override methods to customize debug behavior. Default implementations do nothing.
 */
abstract class WorkmanagerDebug {
    companion object {
        @JvmStatic
        private var current: WorkmanagerDebug = object : WorkmanagerDebug() {}

        /**
         * Set the global debug handler.
         */
        @JvmStatic
        fun setCurrent(handler: WorkmanagerDebug) {
            current = handler
        }

        /**
         * Get the current debug handler.
         */
        @JvmStatic
        fun getCurrent(): WorkmanagerDebug = current

        // Internal methods for the plugin to call
        internal fun onTaskStatusUpdate(
            context: Context,
            taskInfo: TaskDebugInfo,
            status: TaskStatus,
            result: TaskResult? = null,
        ) {
            current.onTaskStatusUpdate(context, taskInfo, status, result)
        }

        internal fun onExceptionEncountered(
            context: Context,
            taskInfo: TaskDebugInfo?,
            exception: Throwable,
        ) {
            current.onExceptionEncountered(context, taskInfo, exception)
        }
    }

    /**
     * Called when a task status changes.
     */
    open fun onTaskStatusUpdate(
        context: Context,
        taskInfo: TaskDebugInfo,
        status: TaskStatus,
        result: TaskResult?,
    ) {
        // Default: do nothing
    }

    /**
     * Called when an exception occurs during task processing.
     */
    open fun onExceptionEncountered(
        context: Context,
        taskInfo: TaskDebugInfo?,
        exception: Throwable,
    ) {
        // Default: do nothing
    }
}
