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
    
}
