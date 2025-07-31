import Foundation
import UserNotifications

/**
 * A debug handler that shows notifications for task events.
 * Note: You need to ensure your app has notification permissions.
 * 
 * @param categoryIdentifier Custom notification category identifier (optional)
 * @param threadIdentifier Custom thread identifier for grouping notifications (optional)
 */
public class NotificationDebugHandler: WorkmanagerDebug {
    private let identifier = UUID().uuidString
    private let startEmoji = "▶️"
    private let retryEmoji = "🔄"
    private let successEmoji = "✅"
    private let failureEmoji = "❌"
    private let stopEmoji = "⏹️"
    
    private let categoryIdentifier: String?
    private let threadIdentifier: String?

    public init(categoryIdentifier: String? = nil, threadIdentifier: String? = nil) {
        self.categoryIdentifier = categoryIdentifier
        self.threadIdentifier = threadIdentifier
        super.init()
    }

    override func onTaskStatusUpdate(taskInfo: TaskDebugInfo, status: TaskStatus, result: TaskResult?) {
        let (emoji, title, message) = formatNotification(taskInfo: taskInfo, status: status, result: result)
        scheduleNotification(
            title: "\(emoji) \(title)",
            body: message
        )
    }

    override func onExceptionEncountered(taskInfo: TaskDebugInfo?, exception: Error) {
        let taskName = taskInfo?.taskName ?? "unknown"
        scheduleNotification(
            title: "\(failureEmoji) Exception",
            body: "\(taskName)\n\(exception.localizedDescription)"
        )
    }

    private func formatNotification(taskInfo: TaskDebugInfo, status: TaskStatus, result: TaskResult?) -> (String, String, String) {
        switch status {
        case .scheduled:
            return ("📅", "Scheduled", taskInfo.taskName)
        case .started:
            return (startEmoji, "Started", taskInfo.taskName)
        case .retrying:
            return (retryEmoji, "Retrying", taskInfo.taskName)
        case .rescheduled:
            return (retryEmoji, "Rescheduled", taskInfo.taskName)
        case .completed:
            let success = result?.success ?? false
            let duration = (result?.duration ?? 0) / 1000
            let emoji = success ? successEmoji : failureEmoji
            let title = success ? "Success \(duration)s" : "Failed \(duration)s"
            return (emoji, title, taskInfo.taskName)
        case .failed:
            let duration = (result?.duration ?? 0) / 1000
            let error = result?.error ?? "Unknown"
            return (failureEmoji, "Failed \(duration)s", "\(taskInfo.taskName)\n\(error)")
        case .cancelled:
            return (stopEmoji, "Cancelled", taskInfo.taskName)
        }
    }

    private func scheduleNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Set category identifier if specified
        if let categoryIdentifier = categoryIdentifier {
            content.categoryIdentifier = categoryIdentifier
        }
        
        // Set thread identifier if specified for grouping
        if let threadIdentifier = threadIdentifier {
            content.threadIdentifier = threadIdentifier
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate delivery
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
}
