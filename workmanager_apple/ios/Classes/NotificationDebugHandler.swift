import Foundation
import UserNotifications

/**
 * A debug handler that shows notifications for task events.
 * Note: You need to ensure your app has notification permissions.
 */
public class NotificationDebugHandler: WorkmanagerDebug {
    private let identifier = UUID().uuidString
    private let workEmojis = ["👷‍♀️", "👷‍♂️"]
    private let successEmoji = "🎉"
    private let failureEmoji = "🔥"
    
    public override init() {}
    
    override func onTaskStatusUpdate(taskInfo: TaskDebugInfo, status: TaskStatus, result: TaskResult?) {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        let (emoji, title, message) = formatNotification(taskInfo: taskInfo, status: status, result: result)
        
        scheduleNotification(
            title: "\(emoji) \(formatter.string(from: Date()))",
            body: "\(title)\n\(message)"
        )
    }
    
    override func onExceptionEncountered(taskInfo: TaskDebugInfo?, exception: Error) {
        let taskName = taskInfo?.taskName ?? "unknown"
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        scheduleNotification(
            title: "\(failureEmoji) \(formatter.string(from: Date()))",
            body: "Exception in Task\n• Task: \(taskName)\n• Error: \(exception.localizedDescription)"
        )
    }
    
    private func formatNotification(taskInfo: TaskDebugInfo, status: TaskStatus, result: TaskResult?) -> (String, String, String) {
        switch status {
        case .scheduled:
            return ("📅", "Task Scheduled", "• Task: \(taskInfo.taskName)\n• Input Data: \(taskInfo.inputData?.description ?? "none")")
        case .started:
            let workEmoji = workEmojis.randomElement() ?? "👷"
            return (workEmoji, "Task Starting", "• Task: \(taskInfo.taskName)\n• Callback Handle: \(taskInfo.callbackHandle ?? -1)")
        case .completed:
            let success = result?.success ?? false
            let duration = result?.duration ?? 0
            let emoji = success ? successEmoji : failureEmoji
            let title = success ? "Task Completed" : "Task Failed"
            var message = "• Task: \(taskInfo.taskName)\n• Duration: \(duration)ms"
            if let error = result?.error {
                message += "\n• Error: \(error)"
            }
            return (emoji, title, message)
        case .failed:
            let error = result?.error ?? "Unknown error"
            return (failureEmoji, "Task Failed", "• Task: \(taskInfo.taskName)\n• Error: \(error)")
        case .cancelled:
            return ("⚠️", "Task Cancelled", "• Task: \(taskInfo.taskName)")
        case .retrying:
            return ("🔄", "Task Retrying", "• Task: \(taskInfo.taskName)")
        }
    }
    
    private func scheduleNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
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