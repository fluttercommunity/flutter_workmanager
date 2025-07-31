import Foundation
import os

/**
 * A debug handler that outputs debug information to iOS's unified logging system.
 */
public class LoggingDebugHandler: WorkmanagerDebug {
    private let logger = os.Logger(subsystem: "dev.fluttercommunity.workmanager", category: "debug")
    
    public override init() {}
    
    override func onTaskStatusUpdate(taskInfo: TaskDebugInfo, status: TaskStatus, result: TaskResult?) {
        switch status {
        case .scheduled:
            logger.debug("Task scheduled: \(taskInfo.taskName)")
        case .started:
            logger.debug("Task started: \(taskInfo.taskName), callbackHandle: \(taskInfo.callbackHandle ?? -1)")
        case .completed:
            let success = result?.success ?? false
            let duration = result?.duration ?? 0
            logger.debug("Task completed: \(taskInfo.taskName), success: \(success), duration: \(duration)ms")
        case .failed:
            let error = result?.error ?? "Unknown error"
            logger.error("Task failed: \(taskInfo.taskName), error: \(error)")
        case .cancelled:
            logger.info("Task cancelled: \(taskInfo.taskName)")
        case .retrying:
            logger.info("Task retrying: \(taskInfo.taskName)")
        }
    }
    
    override func onExceptionEncountered(taskInfo: TaskDebugInfo?, exception: Error) {
        let taskName = taskInfo?.taskName ?? "unknown"
        logger.error("Exception in task: \(taskName), error: \(exception.localizedDescription)")
    }
}