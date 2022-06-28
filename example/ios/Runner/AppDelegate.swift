import UIKit
import Flutter
import workmanager

@UIApplicationMain

@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        GeneratedPluginRegistrant.register(with: self)
        UNUserNotificationCenter.current().delegate = self

        WorkmanagerPlugin.setPluginRegistrantCallback { registry in
            // Registry in this case is the FlutterEngine that is created in Workmanager's
            // performFetchWithCompletionHandler or BGAppRefreshTask.
            // This will make other plugins available during a background operation.
            GeneratedPluginRegistrant.register(with: registry)
        }

        WorkmanagerPlugin.registerTask(withIdentifier: "be.tramckrijte.workmanagerExample.taskId")
        WorkmanagerPlugin.registerTask(withIdentifier: "be.tramckrijte.workmanagerExample.simpleTask")
		WorkmanagerPlugin.registerTask(withIdentifier: "be.tramckrijte.workmanagerExample.rescheduledTask")
		WorkmanagerPlugin.registerTask(withIdentifier: "be.tramckrijte.workmanagerExample.failedTask")
		WorkmanagerPlugin.registerTask(withIdentifier: "be.tramckrijte.workmanagerExample.simpleDelayedTask")
		WorkmanagerPlugin.registerTask(withIdentifier: "be.tramckrijte.workmanagerExample.simplePeriodicTask")
		WorkmanagerPlugin.registerTask(withIdentifier: "be.tramckrijte.workmanagerExample.simplePeriodic1HourTask")

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)

    }

    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
         completionHandler(.alert) // shows banner even if app is in foreground
     }

}
