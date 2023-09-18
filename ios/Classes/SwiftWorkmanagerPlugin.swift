import BackgroundTasks
import Flutter
import os
import UIKit

extension String {
    var lowercasingFirst: String {
        return prefix(1).lowercased() + dropFirst()
    }
}

public class SwiftWorkmanagerPlugin: FlutterPluginAppLifeCycleDelegate {
    static let identifier = "be.tramckrijte.workmanager"

    private var _isInitalized = false
    private static var flutterPluginRegistrantCallback: FlutterPluginRegistrantCallback?

    private struct ForegroundMethodChannel {
        static let channelName = "\(SwiftWorkmanagerPlugin.identifier)/foreground_channel_work_manager"

        struct Methods {
            struct Initialize {
                static let name = "\(Initialize.self)".lowercasingFirst
                enum Arguments: String {
                    case isInDebugMode
                    case callbackHandle
                }
            }

            struct CheckBackgroundRefreshPermission {
                static let name = "\(CheckBackgroundRefreshPermission.self)".lowercasingFirst
            }

            struct RegisterOneOffTask {
                static let name = "\(RegisterOneOffTask.self)".lowercasingFirst
                enum Arguments: String {
                    case taskName
                    case uniqueName
                    case inputData
                    case initialDelaySeconds
                }
            }

            struct RegisteriOSBackgroundProcessingTask {
                static let name = "\(RegisteriOSBackgroundProcessingTask.self)".lowercasingFirst
                enum Arguments: String {
                    case taskName
                    case uniqueName
                    case initialDelaySeconds
                    case networkType
                    case requiresCharging
                }
            }

            struct RegisterPeriodicTask {
                static let name = "\(RegisterPeriodicTask.self)".lowercasingFirst
                enum Arguments: String {
                    case taskName
                    case uniqueName
                    case initialDelaySeconds
                }
            }

            struct CancelAllTasks {
                static let name = "\(CancelAllTasks.self)".lowercasingFirst
                enum Arguments: String {
                    case none
                }
            }

            struct CancelTaskByUniqueName {
                static let name = "\(CancelTaskByUniqueName.self)".lowercasingFirst
                enum Arguments: String {
                    case uniqueName
                }
            }
        }
    }

    @available(iOS 13.0, *)
    private static func handleBGProcessingTask(_ task: BGProcessingTask) {
        NSLog("Workmanagerplugin handle handleBGProcessingTask")
        let operationQueue = OperationQueue()

        // Create an operation that performs the main part of the background task
        let operation = BackgroundTaskOperation(
            task.identifier,
            inputData: "", //no data
            flutterPluginRegistrantCallback: SwiftWorkmanagerPlugin.flutterPluginRegistrantCallback,
            backgroundMode: .backgroundProcessingTask,
            isInDebug: UserDefaultsHelper.getIsDebug()
        )

        // Provide an expiration handler for the background task
        // that cancels the operation
        task.expirationHandler = {
            operation.cancel()
        }

        // Inform the system that the background task is complete
        // when the operation completes
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }

        // Start the operation
        operationQueue.addOperation(operation)
    }

    @objc
    @available(iOS 13.0, *)
    public static func handleAppRefresh(task: BGAppRefreshTask) {
        NSLog("Workmanagerplugin handle BGAppRefreshTask")
        guard let callbackHandle = UserDefaultsHelper.getStoredCallbackHandle(),
              let _ = FlutterCallbackCache.lookupCallbackInformation(callbackHandle)
        else {
            logError("[\(String(describing: self))] \(WMPError.workmanagerNotInitialized.message)")
            return
        }

        /// Could improved _ seconds are ignored on refresh //important to reschedule
        scheduleAppRefresh(taskIdentifier: task.identifier, earliestBeginInSeconds: 120)

        NSLog("Workmanagerplugin handle BGAppRefreshTask")
        let operationQueue = OperationQueue()
        // Create an operation that performs the main part of the background task
        let operation = BackgroundTaskOperation(
            task.identifier,
            inputData: "",
            flutterPluginRegistrantCallback: SwiftWorkmanagerPlugin.flutterPluginRegistrantCallback,
            backgroundMode: .backgroundAppRefresh,
            isInDebug: UserDefaultsHelper.getIsDebug()
        )

        // Provide an expiration handler for the background task
        // that cancels the operation
        task.expirationHandler = {
            operation.cancel()
        }

        // Inform the system that the background task is complete
        // when the operation completes
        operation.completionBlock = {
            NSLog("Workmanagerplugin handle BGAppRefreshTask completed")
            task.setTaskCompleted(success: !operation.isCancelled)
        }

        // Start the operation
        operationQueue.addOperation(operation)
        // Create an operation that performs the main part of the background task.
    }

    /// Initialisation for all Tasks

    @available(iOS 13.0, *)
    /// Immedately start a background fetch with 29sec timeout - specification by iOS
    public static func startOnOffTask(identifier: String, taskIdentifier: UIBackgroundTaskIdentifier, inputData:String, delaySeconds: Int64) {
        NSLog("Workmanagerplugin immedately startOnOffTask alias iOS backgroundFetch started - timeout after 30sec.")

        let operationQueue = OperationQueue()
        // Create an operation that performs the main part of the background task
        let operation = BackgroundTaskOperation(
            identifier,
            inputData: inputData,
            flutterPluginRegistrantCallback: SwiftWorkmanagerPlugin.flutterPluginRegistrantCallback,
            backgroundMode: .backgroundOnOffTask(identifier: identifier),
            isInDebug: UserDefaultsHelper.getIsDebug()
        )

        // Inform the system that the task is complete when the operation completes
        operation.completionBlock = {
            NSLog("Background task ended \(identifier) : ID:\(taskIdentifier).")
            UIApplication.shared.endBackgroundTask(taskIdentifier)
        }

        // Start the operation
        operationQueue.addOperation(operation)
        // Create an operation that performs the main part of the background task.
    }

    /// First register names for [BGAppRefresh].
    /// You must register task names before app finishes launching in AppDelegate.
    /// After that you can call [registerAppRefreshTaskScheduler] which schedules task in background
    @objc
    public static func registerAppRefreshTask(withIdentifier identifier: String) {
        if #available(iOS 13.0, *) {
            print("Workmanager - registerAppRefreshTask withIdentifier \(identifier)")

            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: identifier,
                using: nil
            ) { task in
                if let task = task as? BGAppRefreshTask {
                    handleAppRefresh(task: task)
                }
            }
        }
    }

    /// App Refresh - called by iOS in background at random time for a max 30 sec task
    @objc
    public static func registerAppRefreshTaskScheduler(
        taskIdentifier identifier: String,
        earliestBeginInSeconds begin: Double) {
        if #available(iOS 13.0, *) {
            print("Workmanager - registerAppRefreshTaskScheduler withIdentifier \(identifier)")
            // schedule on app did enter background
            NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil, queue: nil
            ) { _ in
                // schedule apprefresh
                scheduleAppRefresh(taskIdentifier: identifier, earliestBeginInSeconds: begin)
            }
        }
    }

    @objc
    @available(iOS 13.0, *)
    private static func scheduleAppRefresh(taskIdentifier identifier: String, earliestBeginInSeconds begin: Double) {
        let request = BGAppRefreshTaskRequest(
            identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: begin)
        do {
            try BGTaskScheduler.shared.submit(request)
            print("scheduleAppRefresh workmanager (re)scheduled app refresh \(identifier)")
        } catch {
            print("Couldn't schedule app refresh \(error.localizedDescription)")
            return
        }
    }

    /// First register names for BGProcessingTask called by WorkmangerPlugin.m
    /// This happens on registering
    /// you must register task names before app finishes launching in AppDelegate --> else there is an error thrown
    /// After that you can call [registerProcessingTaskScheduler] which schedules task in background
    @objc
    public static func registerBGProcessingTask(withIdentifier identifier: String) {
        if #available(iOS 13.0, *) {
            print("Workmanager - registerBackgroundProcessingTask withIdentifier \(identifier)")
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: identifier,
                using: nil
            ) { task in
                if let task = task as? BGProcessingTask {
                    handleBGProcessingTask(task)
                }
            }
        }
    }

    @objc
    /// Registers a long running BackgroundProcessingTask - randomly started by iOS when app in background
    /// Task will scheduled when app goes to background
    public static func registerBackgroundProcessingTaskScheduler(uniqueTaskIdentifier: String,
                                                                 earliestBeginInSeconds begin: Double,
                                                                 requiresNetworkConnectivity: Bool,
                                                                 requiresExternalPower: Bool) {
        if #available(iOS 13.0, *) {
            // avoid XCode line length issue in notificationcenterobserver maxx 200 chars line length
            let network = requiresNetworkConnectivity
            let extPower = requiresExternalPower
            print("Workmanager - registerBackgroundProcessingTaskScheduler withIdentifier \(uniqueTaskIdentifier)")

            NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil, queue: nil
            ) { _ in
                // schedule apprefresh
                scheduleBackgroundProcessingTask(withIdentifier: uniqueTaskIdentifier, earliestBeginInSeconds: begin, requiresNetworkConnectivity: network, requiresExternalPower: extPower)
            }
        }
    }

    @objc
    /// Schedules a long running BackgroundProcessingTask - randomly started by iOS when app in background
    /// Called by UIApplication.didEnterBackgroundNotification in [registerBackgroundProcessingTaskScheduler]
    @available(iOS 13.0, *)
    private static func scheduleBackgroundProcessingTask(
        withIdentifier uniqueTaskIdentifier: String,
        earliestBeginInSeconds begin: Double,
        requiresNetworkConnectivity: Bool,
        requiresExternalPower: Bool
    ) {
        let request = BGProcessingTaskRequest(
            identifier: uniqueTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: begin)
        request.requiresNetworkConnectivity = requiresNetworkConnectivity
        request.requiresExternalPower = requiresExternalPower
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Requested BackgroundProcessingTask  \(uniqueTaskIdentifier)")
        } catch {
            print("Couldn't schedule app BackgroundProcessingTask identifier:\(uniqueTaskIdentifier) error:\(error.localizedDescription)")
            print("On BGTaskSchedulerErrorDomain error 1 - please run on real device")
            print("On BGTaskSchedulerErrorDomain error 3 - check registered names")
        }
    }

    static func callback(_: UIBackgroundFetchResult) {
    }
}

// MARK: - FlutterPlugin conformance

extension SwiftWorkmanagerPlugin: FlutterPlugin {
    @objc
    public static func setPluginRegistrantCallback(_ callback: @escaping FlutterPluginRegistrantCallback) {
        flutterPluginRegistrantCallback = callback
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let foregroundMethodChannel = FlutterMethodChannel(
            name: ForegroundMethodChannel.channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = SwiftWorkmanagerPlugin()
        registrar.addMethodCallDelegate(instance, channel: foregroundMethodChannel)
        registrar.addApplicationDelegate(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch (call.method, call.arguments as? [AnyHashable: Any]) {
        case (ForegroundMethodChannel.Methods.Initialize.name, let .some(arguments)):
            initialize(arguments: arguments, result: result)
            return
        case (ForegroundMethodChannel.Methods.CheckBackgroundRefreshPermission.name, .some):
            _ = checkBackgroundRefreshAuthorisation(result: result)
            return
        case (ForegroundMethodChannel.Methods.RegisterPeriodicTask.name, let .some(arguments)):
            // register bgAppRefreshTask for less than 30 seconds backgroundtime
            registerPeriodicTask(arguments: arguments, result: result)
            return
        case (ForegroundMethodChannel.Methods.RegisterOneOffTask.name, let .some(arguments)):
            // register processingtask for less  than 30 seconds backgroundtime
            // Task starts immedatly
            registerOneOffTask(arguments: arguments, result: result)
            return
        case (ForegroundMethodChannel.Methods.RegisteriOSBackgroundProcessingTask.name, let .some(arguments)):
            // register long running iOs BGProcessingtask for more than 30 seconds backgroundtime
            registerBackgroundProcessingTask(arguments: arguments, result: result)
            return
        case (ForegroundMethodChannel.Methods.CancelAllTasks.name, .none):
            cancelAllTasks(result: result)
            return
        case (ForegroundMethodChannel.Methods.CancelTaskByUniqueName.name, let .some(arguments)):
            cancelTaskByUniqueName(arguments: arguments, result: result)
            return
        default:
            result(WMPError.unhandledMethod(call.method).asFlutterError)
            return
        }
    }

    private func initialize(arguments: [AnyHashable: Any], result: @escaping FlutterResult) {
        if _isInitalized {
            result(WMPError.workmanagerIsAlreadyInitialized)
            return
        }
        #if targetEnvironment(simulator)
            print("Workmanager Info: Please run on real device!" +
                "No backgroundtask is automatic called in the simulator!!")
        #endif
        let backgroundRefreshAvailable = checkBackgroundRefreshAuthorisation(result: result)
        if backgroundRefreshAvailable != BackgroundAuthorisationState.available {
            UIApplication.shared.open(URL(
                string: UIApplication.openSettingsURLString)!,
            options: [:],
            completionHandler: nil)
            return
        }
        let method = ForegroundMethodChannel.Methods.Initialize.self
        guard let isInDebug = arguments[method.Arguments.isInDebugMode.rawValue] as? Bool,
              let handle = arguments[method.Arguments.callbackHandle.rawValue] as? Int64 else {
            result(WMPError.invalidParameters.asFlutterError)
            return
        }
        UserDefaultsHelper.storeCallbackHandle(handle)
        UserDefaultsHelper.storeIsDebug(isInDebug)
    }

    private func registerPeriodicTask(arguments: [AnyHashable: Any], result: @escaping FlutterResult) {
        print("Registering periodic task in background (BGAppRefreshTask)")
        if !validateCallbackHandle(result: result) {
            return
        }

        if #available(iOS 13.0, *) {
            let method = ForegroundMethodChannel.Methods.RegisterPeriodicTask.self
            guard let uniqueTaskIdentifier =
                arguments[method.Arguments.uniqueName.rawValue] as? String else {
                result(WMPError.invalidParameters.asFlutterError)
                return
            }
            let initialDelaySeconds =
                arguments[method.Arguments.initialDelaySeconds.rawValue] as? Int64 ?? 0
            // task will scheduled when app goes to background
            SwiftWorkmanagerPlugin.registerAppRefreshTaskScheduler(
                taskIdentifier: uniqueTaskIdentifier,
                earliestBeginInSeconds: Double(initialDelaySeconds))
            print("Registered PeriodicTask \(uniqueTaskIdentifier) , callbackId \(uniqueTaskIdentifier.lowercasingFirst) delaySeconds \(initialDelaySeconds)")
            result(true)
            return
        } else {
            result(FlutterError(code: "99",
                                message: "RegisterPeriodicTask is not registered",
                                details: "iOS Version lower than 13.0"))
        }
    }

    private func registerOneOffTask(arguments: [AnyHashable: Any], result: @escaping FlutterResult) {
        print("Registering OneOffTask")
        if !validateCallbackHandle(result: result) {
            return
        }
        if #available(iOS 13.0, *) {
            let method = ForegroundMethodChannel.Methods.RegisterOneOffTask.self
            guard let delaySeconds =
                arguments[method.Arguments.initialDelaySeconds.rawValue] as? Int64 else {
                result(WMPError.invalidParameters.asFlutterError)
                return
            }
            guard let uniqueTaskIdentifier =
                arguments[method.Arguments.uniqueName.rawValue] as? String else {
                result(WMPError.invalidParameters.asFlutterError)
                return
            }
            guard let callBackIdentifier =
                arguments[method.Arguments.taskName.rawValue] as? String else {
                result(WMPError.invalidParameters.asFlutterError)
                return
            }
            var taskIdentifier: UIBackgroundTaskIdentifier = .invalid
            let inputData =
                    arguments[method.Arguments.inputData.rawValue] as? String


            taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: uniqueTaskIdentifier, expirationHandler: {
                // Code to handle if takes way too long
                UIApplication.shared.endBackgroundTask(taskIdentifier)
            })
            SwiftWorkmanagerPlugin.startOnOffTask(identifier: callBackIdentifier,
                                                  taskIdentifier: taskIdentifier,
                                                  inputData: inputData ?? "",
                                                  delaySeconds: delaySeconds)
            result(true)
            print("Registered OnOffTask \(uniqueTaskIdentifier) , callbackId \(uniqueTaskIdentifier.lowercasingFirst)")
            return
        } else {
            result(FlutterError(code: "99",
                                message: "RegisterPeriodicTask is not registered",
                                details: "iOS Version lower than 13.0"))
        }
    }

    private func registerBackgroundProcessingTask(arguments: [AnyHashable: Any], result: @escaping FlutterResult) {
        print("Registering backgroundProcessingTask")
        if !validateCallbackHandle(result: result) {
            return
        }
        if #available(iOS 13.0, *) {
            let method = ForegroundMethodChannel.Methods.RegisteriOSBackgroundProcessingTask.self
            guard let uniqueTaskIdentifier =
                arguments[method.Arguments.uniqueName.rawValue] as? String else {
                result(WMPError.invalidParameters.asFlutterError)
                return
            }
            let delaySeconds =
                arguments[method.Arguments.initialDelaySeconds.rawValue] as? Double ?? 0.0

            let requiresCharging = arguments[method.Arguments.requiresCharging.rawValue] as? Bool ?? false
            var requiresNetwork = false
            if let networkTypeInput = arguments[method.Arguments.networkType.rawValue] as? String,
               let networkType = NetworkType(fromDart: networkTypeInput),
               networkType == .connected || networkType == .metered {
                requiresNetwork = true
            }

            // task will scheduled by iOS when app goes to background
            SwiftWorkmanagerPlugin.registerBackgroundProcessingTaskScheduler(
                uniqueTaskIdentifier: uniqueTaskIdentifier,
                earliestBeginInSeconds: delaySeconds,
                requiresNetworkConnectivity: requiresCharging,
                requiresExternalPower: requiresNetwork)
            result(true)
            print("Registered BackgroundProcessingTask \(uniqueTaskIdentifier) , callbackId \(uniqueTaskIdentifier.lowercasingFirst)")

            return
        } else {
            result(FlutterError(code: "99",
                                message: "BackgroundProcessingTask is not registered",
                                details: "iOS Version lower than 13.0"))
        }
    }

    private func cancelAllTasks(result: @escaping FlutterResult) {
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.cancelAllTaskRequests()
        }
        result(true)
    }

    private func cancelTaskByUniqueName(arguments: [AnyHashable: Any], result: @escaping FlutterResult) {
        if #available(iOS 13.0, *) {
            let method = ForegroundMethodChannel.Methods.CancelTaskByUniqueName.self
            guard let identifier = arguments[method.Arguments.uniqueName.rawValue] as? String else {
                result(WMPError.invalidParameters.asFlutterError)
                return
            }
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        }
        result(true)
    }

    /// Checks wether getStoredCallbackHandle is set
    /// Returns true wenn initilized
    /// if false result contains errormessage
    private func validateCallbackHandle(result: @escaping FlutterResult) -> Bool {
        if UserDefaultsHelper.getStoredCallbackHandle() == nil {
            result(
                FlutterError(
                    code: "1",
                    message: "You have not properly initialized the Flutter WorkManager Package. " +
                        "You should ensure you have called the 'initialize' function first! " +
                        "Example: \n" +
                        "\n" +
                        "`Workmanager().initialize(\n" +
                        "  callbackDispatcher,\n" +
                        " )`" +
                        "\n" +
                        "\n" +
                        "The `callbackDispatcher` is a top level function. See example in repository.",
                    details: nil
                )
            )
            return false
        }
        return true
    }
}

// MARK: - AppDelegate conformance

extension SwiftWorkmanagerPlugin {
    override public func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) -> Bool {
        let worker = BackgroundWorker(
            mode: .backgroundProcessingTask,
            inputData: "", 
            flutterPluginRegistrantCallback: SwiftWorkmanagerPlugin.flutterPluginRegistrantCallback
        )
        return worker.performBackgroundRequest(completionHandler)
    }
}
