import Foundation
import os

/**
 * Protocol for handling debug events in Workmanager.
 * Implement this protocol to customize how debug information is handled.
 */
public protocol WorkmanagerDebugHandler {
    /**
     * Called when a background task starts executing.
     */
    func onTaskStarting(taskInfo: TaskDebugInfo)
    
    /**
     * Called when a background task completes execution.
     */
    func onTaskCompleted(taskInfo: TaskDebugInfo, result: TaskResult)
}

/**
 * Information about a task for debugging purposes.
 */
public struct TaskDebugInfo {
    public let taskName: String
    public let uniqueName: String?
    public let inputData: [String: Any]?
    public let startTime: Date
    public let callbackHandle: Int64?
    public let callbackInfo: String?
    
    public init(taskName: String, uniqueName: String? = nil, inputData: [String: Any]? = nil, startTime: Date, callbackHandle: Int64? = nil, callbackInfo: String? = nil) {
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
    public let duration: TimeInterval
    public let error: String?
    
    public init(success: Bool, duration: TimeInterval, error: String? = nil) {
        self.success = success
        self.duration = duration
        self.error = error
    }
}

/**
 * Global debug handler registry for Workmanager.
 * Allows developers to set custom debug handlers.
 */
public class WorkmanagerDebug {
    private static var debugHandler: WorkmanagerDebugHandler?
    
    /**
     * Set a custom debug handler. Pass nil to disable debug handling.
     */
    public static func setDebugHandler(_ handler: WorkmanagerDebugHandler?) {
        debugHandler = handler
    }
    
    /**
     * Get the current debug handler, if any.
     */
    public static func getDebugHandler() -> WorkmanagerDebugHandler? {
        return debugHandler
    }
    
    internal static func onTaskStarting(taskInfo: TaskDebugInfo) {
        debugHandler?.onTaskStarting(taskInfo: taskInfo)
    }
    
    internal static func onTaskCompleted(taskInfo: TaskDebugInfo, result: TaskResult) {
        debugHandler?.onTaskCompleted(taskInfo: taskInfo, result: result)
    }
}