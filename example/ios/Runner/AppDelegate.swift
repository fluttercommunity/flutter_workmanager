import UIKit
import Flutter
import workmanager

@UIApplicationMain

@objc class AppDelegate: FlutterAppDelegate {
    
    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        GeneratedPluginRegistrant.register(with: self)
        UNUserNotificationCenter.current().delegate = self
        
        WorkmanagerPlugin.setPluginRegistrantCallback { registry in
            // registry in this case is the FlutterEngine that is created in Workmanager's performFetchWithCompletionHandler
            // This will make other plugins available during a background fetch
            GeneratedPluginRegistrant.register(with: registry)
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        
    }
    
    override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
         completionHandler(.alert) // shows banner even if app is in foreground
     }
    
}
