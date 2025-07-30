package dev.fluttercommunity.workmanager

import android.content.Context

/**
 * Interface for handling debug events in Workmanager.
 * Implement this interface to customize how debug information is handled.
 */
interface WorkmanagerDebugHandler {
    /**
     * Called when a background task starts executing.
     */
    fun onTaskStarting(
        context: Context,
        taskInfo: TaskDebugInfo,
    )

    /**
     * Called when a background task completes execution.
     */
    fun onTaskCompleted(
        context: Context,
        taskInfo: TaskDebugInfo,
        result: TaskResult,
    )
}

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
 * Global debug handler registry for Workmanager.
 * Allows developers to set custom debug handlers.
 */
object WorkmanagerDebug {
    private var debugHandler: WorkmanagerDebugHandler? = null

    /**
     * Set a custom debug handler. Pass null to disable debug handling.
     */
    fun setDebugHandler(handler: WorkmanagerDebugHandler?) {
        debugHandler = handler
    }

    /**
     * Get the current debug handler, if any.
     */
    fun getDebugHandler(): WorkmanagerDebugHandler? = debugHandler

    internal fun onTaskStarting(
        context: Context,
        taskInfo: TaskDebugInfo,
    ) {
        debugHandler?.onTaskStarting(context, taskInfo)
    }

    internal fun onTaskCompleted(
        context: Context,
        taskInfo: TaskDebugInfo,
        result: TaskResult,
    ) {
        debugHandler?.onTaskCompleted(context, taskInfo, result)
    }
}
