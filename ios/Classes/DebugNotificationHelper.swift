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
        Starting Dart/Flutter with following params:
         • callbackHandle: '\(callBackHandle)'
         • callBackName: '\(callbackInfo.callbackName ?? "not found")'
         • callbackClassName: '\(callbackInfo.callbackClassName ?? "not found")'
         • callbackLibraryPath: '\(callbackInfo.callbackLibraryPath ?? "not found")'
        """
        DebugNotificationHelper.scheduleNotification(identifier: identifier.uuidString,
                                                     title: startDate.formatted(),
                                                     body: message,
                                                     icon: .startWork)
    }
    
    static func showCompletedFetchNotification(identifier: UUID, completedDate: Date, result: UIBackgroundFetchResult, elapsedTime: TimeInterval) {
        let message =
        """
        Perform fetch completed:
         • Elapsed time: \(elapsedTime.formatToSeconds())
         • Result: UIBackgroundFetchResult.\(result)
        """
        DebugNotificationHelper.scheduleNotification(identifier: identifier.uuidString,
                                                     title: completedDate.formatted(),
                                                     body: message,
                                                     icon: result == .newData ? .success : .failure)
    }
    
    
    // MARK: -  Private helper functions
    
    private static func scheduleNotification(identifier: String, title: String, body: String, icon: ThumbnailGenerator.ThumbnailIcon) {
        guard UserDefaultsHelper.getIsDebug(), #available(iOS 10.0, *) else {
            logInfo("\(logPrefix) \(#function): plugin is not running in debug mode or on iOS 9 or lower")
            return
        }
        
        func scheduleLocalNotification() {
            DispatchQueue.main.async {
                let notificationRequest = createNotificationRequest(identifier: identifier, threadIdentifier: SwiftWorkmanagerPlugin.identifier, title: title, body: body, icon: icon)
                UNUserNotificationCenter.current().add(notificationRequest, withCompletionHandler: nil)
            }
        }
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                scheduleLocalNotification()
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .alert]) { (success, error) in
                    guard success && (error == nil) else {
                        logInfo("\(logPrefix) \(#function): plugin is running in debug mode but can't schedule local notifications because is not authorized")
                        return
                    }
                    scheduleLocalNotification()
                }
            case .denied:
                logInfo("\(logPrefix) \(#function): plugin is running in debug mode but can't schedule local notifications because is not authorized")
                
            }
        }
    }
    
    @available(iOS 10.0, *)
    private static func createNotificationRequest(identifier: String, threadIdentifier: String, title: String, body: String, icon: ThumbnailGenerator.ThumbnailIcon) -> UNNotificationRequest {
        let notification = UNMutableNotificationContent()
        notification.title = title
        notification.body = body
        notification.threadIdentifier = threadIdentifier
        if let thumbnail = ThumbnailGenerator.createThumbnail(with: icon) {
            notification.attachments = [thumbnail]
        }
        let immediateFutureTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let notificationRequest = UNNotificationRequest(identifier: identifier, content: notification, trigger: immediateFutureTrigger)
        
        return notificationRequest
    }
    
    private static var logPrefix: String {
        return "\(String(describing: SwiftWorkmanagerPlugin.self)) - \(DebugNotificationHelper.self)"
    }
    
}
