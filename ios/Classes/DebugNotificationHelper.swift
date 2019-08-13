//
//  LocalNotificationHelper.swift
//  workmanager
//
//  Created by Kymer Gryson on 12/08/2019.
//

import Foundation
import UserNotifications

struct DebugNotificationHelper {
    
    static func showStartFetchNotification(identifier: UUID, startDate: Date, callBackHandle: Int64, callbackInfo: FlutterCallbackInformation) {
        let message =
        """
        Trying to start Dart/Flutter with following params:
         • callbackHandle: '\(callBackHandle)'
         • callBackName: '\(callbackInfo.callbackName ?? "not found")'
         • callbackClassName: '\(callbackInfo.callbackClassName ?? "not found")'
         • callbackLibraryPath: '\(callbackInfo.callbackLibraryPath ?? "not found")'
        """

        DebugNotificationHelper.scheduleNotification(identifier: identifier.uuidString, title: startDate.formatted(), body: message)
    }
    
    static func showCompletedFetchNotification(identifier: UUID, completedDate: Date, result: UIBackgroundFetchResult, elapsedTime: TimeInterval) {
        let message =
        """
        Perform fetch completed:
         • Elapsed time: \(elapsedTime.formatted())
         • Result: UIBackgroundFetchResult.\(result)
        """
        
        DebugNotificationHelper.scheduleNotification(identifier: identifier.uuidString, title: completedDate.formatted(), body: message)
    }
    
    
    // MARK: -  Private helper functions
    
    private static func scheduleNotification(identifier: String, title: String, body: String) {
        guard UserDefaultsHelper.getIsDebug(), #available(iOS 10.0, *) else {
            logInfo("\(logPrefix) \(#function): plugin is not running in debug mode or on iOS 9 or lower")
            return
        }

        DebugNotificationHelper.requestAuthorization()
        let notification = UNMutableNotificationContent()
        notification.title = title
        notification.body = body
        notification.threadIdentifier = SwiftWorkmanagerPlugin.identifier
        if let thumbnail = createThumbnail(emoji: "🚀") {
            notification.attachments = [thumbnail]
        }
        let immediateFutureTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let notificationRequest = UNNotificationRequest(identifier: identifier, content: notification, trigger: immediateFutureTrigger)
        
        UNUserNotificationCenter.current().add(notificationRequest, withCompletionHandler: nil)
    }
    
    private static func requestAuthorization() {
        guard UserDefaultsHelper.getIsDebug(), #available(iOS 10.0, *) else {
            logInfo("\(logPrefix) \(#function): plugin is not running in debug mode or on iOS 9 or lower")
            return
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .alert]) { (success, error) in
            let message =
            """
            "\(logPrefix): \(#function)
             • Success: \(success)"
             • Error: \(error?.localizedDescription ?? "nil")
            """
            
            logInfo(message)
        }
    }
    
    private static var logPrefix: String {
        return "\(String(describing: SwiftWorkmanagerPlugin.self)) - \(DebugNotificationHelper.self)"
    }
    
    @available(iOS 10.0, *)
    private static func createThumbnail(emoji: String) -> UNNotificationAttachment? {
        let name = "thumbnail"
        let thumbnailFrame = CGRect(x: 0, y: 0, width: 150, height: 150)
        let thumbnail = UIView(frame: thumbnailFrame)
        thumbnail.isOpaque = false
        let label = UILabel(frame: thumbnailFrame)
        label.text = emoji
        label.font = UIFont.systemFont(ofSize: 125)
        label.textAlignment = .center
        thumbnail.addSubview(label)
        
        do {
            let thumbnailImage = try thumbnail.renderAsImage()
            let localURL = try thumbnailImage.persist(fileName: name)
            return try UNNotificationAttachment(identifier: "\(SwiftWorkmanagerPlugin.identifier).\(name)", url: localURL, options: nil)
        } catch {
            logInfo("\(logPrefix) \(#function) something went wrong creating a thumbnail for local debug notification")
            return nil
        }
        
    }
    
}

private extension UIView {
    
    func renderAsImage() throws -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, self.isOpaque, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            throw error.noCurrentGraphicsContextFound
        }
        self.layer.render(in: context)
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            throw error.noCurrentGraphicsContextFound
        }
        
        return image
    }
    
    enum error: Error {
        case noCurrentGraphicsContextFound
    }
}

private extension UIImage {
    
    func persist(fileName: String, in directory: URL = URL(fileURLWithPath: NSTemporaryDirectory())) throws -> URL {
        let directoryURL = directory.appendingPathComponent(SwiftWorkmanagerPlugin.identifier, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("\(fileName).png")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        guard let imageData = UIImagePNGRepresentation(self) else {
            throw error.cannotRepresentAsPNG(self)
        }
        try imageData.write(to: fileURL)
        
        return fileURL
    }
    
    enum error: Error {
        case cannotRepresentAsPNG(UIImage)
    }
    
}
