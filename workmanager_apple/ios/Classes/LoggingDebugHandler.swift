import Foundation
import os

/**
 * A debug handler that outputs debug information to iOS's unified logging system.
 * Use this for development to see task execution in the console and Xcode logs.
 */
public class LoggingDebugHandler: WorkmanagerDebugHandler {
    private let logger = os.Logger(subsystem: "dev.fluttercommunity.workmanager", category: "debug")
    
    public init() {}
    
    public func onTaskStarting(taskInfo: TaskDebugInfo) {
        logger.debug("Task starting: \(taskInfo.taskName), callbackHandle: \(taskInfo.callbackHandle ?? -1)")
    }
    
    public func onTaskCompleted(taskInfo: TaskDebugInfo, result: TaskResult) {
        let status = result.success ? "SUCCESS" : "FAILURE"
        logger.debug("Task completed: \(taskInfo.taskName), result: \(status), duration: \(String(format: "%.2f", result.duration))s")
        
        if let error = result.error {
            logger.error("Task error: \(error)")
        }
    }
}