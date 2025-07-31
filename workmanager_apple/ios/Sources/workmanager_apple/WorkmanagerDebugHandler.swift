import Foundation
import os

/**
 * Information about a task for debugging purposes.
 */
public struct TaskDebugInfo {
    public let taskName: String
    public let uniqueName: String?
    public let inputData: [String: Any]?
    public let startTime: TimeInterval
    public let callbackHandle: Int64?
    public let callbackInfo: String?

    public init(taskName: String, uniqueName: String? = nil, inputData: [String: Any]? = nil, startTime: TimeInterval, callbackHandle: Int64? = nil, callbackInfo: String? = nil) {
        self.taskName = taskName
        self.uniqueName = uniqueName
        self.inputData = inputData
        self.startTime = startTime
        self.callbackHandle = callbackHandle
        self.callbackInfo = callbackInfo
    }
}

/**
 * Result information for a completed task.
 */
public struct TaskResult {
    public let success: Bool
    public let duration: Int64
    public let error: String?

    public init(success: Bool, duration: Int64, error: String? = nil) {
        self.success = success
        self.duration = duration
        self.error = error
    }
}

/**
 * Abstract debug handler for Workmanager events.
 * Override methods to customize debug behavior. Default implementations do nothing.
 */
public class WorkmanagerDebug {
    private static var current: WorkmanagerDebug = WorkmanagerDebug()

    /**
     * Set the global debug handler.
     */
    public static func setCurrent(_ handler: WorkmanagerDebug) {
        current = handler
    }

    /**
     * Get the current debug handler.
     */
    public static func getCurrent() -> WorkmanagerDebug {
        return current
    }

    /**
     * Called when a task status changes.
     */
    func onTaskStatusUpdate(taskInfo: TaskDebugInfo, status: TaskStatus, result: TaskResult?) {
        // Default: do nothing
    }

    /**
     * Called when an exception occurs during task processing.
     */
    func onExceptionEncountered(taskInfo: TaskDebugInfo?, exception: Error) {
        // Default: do nothing
    }

    // Internal methods for the plugin to call
    internal static func onTaskStatusUpdate(taskInfo: TaskDebugInfo, status: TaskStatus, result: TaskResult? = nil) {
        current.onTaskStatusUpdate(taskInfo: taskInfo, status: status, result: result)
    }

    internal static func onExceptionEncountered(taskInfo: TaskDebugInfo?, exception: Error) {
        current.onExceptionEncountered(taskInfo: taskInfo, exception: exception)
    }
}
