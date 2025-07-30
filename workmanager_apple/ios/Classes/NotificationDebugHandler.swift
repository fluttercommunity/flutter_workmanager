import Foundation
import UserNotifications

/**
 * A debug handler that shows notifications for task events.
 * Use this to see task execution as notifications on the device.
 * 
 * Note: You need to ensure your app has notification permissions.
 */
public class NotificationDebugHandler: WorkmanagerDebugHandler {
    private let identifier = UUID().uuidString
    private let workEmojis = ["👷‍♀️", "👷‍♂️"]
    private let successEmoji = "🎉"
    private let failureEmoji = "🔥"
    
    public init() {}
    
    public func onTaskStarting(taskInfo: TaskDebugInfo) {
        let workEmoji = workEmojis.randomElement() ?? "👷"
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        let message = """
        • Task Starting: \(taskInfo.taskName)
        • Input Data: \(taskInfo.inputData?.description ?? "none")
        • Callback Handle: \(taskInfo.callbackHandle ?? -1)
        """
        
        scheduleNotification(
            title: "\(workEmoji) \(formatter.string(from: taskInfo.startTime))",
            body: message
        )
    }
    
    public func onTaskCompleted(taskInfo: TaskDebugInfo, result: TaskResult) {
        let workEmoji = workEmojis.randomElement() ?? "👷"
        let resultEmoji = result.success ? successEmoji : failureEmoji
        let status = result.success ? "SUCCESS" : "FAILURE"
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        var message = """
        • Result: \(resultEmoji) \(status)
        • Task: \(taskInfo.taskName)
        • Input Data: \(taskInfo.inputData?.description ?? "none")
        • Duration: \(String(format: "%.2f", result.duration))s
        """
        
        if let error = result.error {
            message += "\n• Error: \(error)"
        }
        
        scheduleNotification(
            title: "\(workEmoji) \(formatter.string(from: Date()))",
            body: message
        )
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