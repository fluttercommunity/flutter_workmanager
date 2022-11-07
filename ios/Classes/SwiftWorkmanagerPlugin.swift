import BackgroundTasks
import Flutter
import UIKit
import os

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
                    case uniqueName
                    case initialDelaySeconds
                    case networkType
                    case requiresCharging
                }
            }
            struct RegisterPeriodicTask {
                static let name = "\(RegisterPeriodicTask.self)".lowercasingFirst
                enum Arguments: String {
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

    // Handlers
    @available(iOS 13.0, *)
    private static func handleBGProcessingTask(_ task: BGProcessingTask) {
        let operationQueue = OperationQueue()

        // Create an operation that performs the main part of the background task
        let operation = BackgroundTaskOperation(
            task.identifier,
            flutterPluginRegistrantCallback: SwiftWorkmanagerPlugin.flutterPluginRegistrantCallback
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
        guard let callbackHandle = UserDefaultsHelper.getStoredCallbackHandle(),
              let flutterCallbackInformation = FlutterCallbackCache.lookupCallbackInformation(callbackHandle)
        else {
            logError("[\(String(describing: self))] \(WMPError.workmanagerNotInitialized.message)")
            return
        }

        let taskSessionStart = Date()
        let taskSessionIdentifier = UUID()

        let debugHelper = DebugNotificationHelper(taskSessionIdentifier)
        debugHelper.showStartBGRefreshNotification(
            startDate: taskSessionStart,
            callBackHandle: callbackHandle,
            callbackInfo: flutterCallbackInformation
        )
        /// Could improved _ seconds are ignored
        scheduleAppRefresh(withIdentifier: task.identifier, earliestBeginInSeconds: 120)
        let semaphore = DispatchSemaphore(value: 0)

        DispatchQueue.main.async {
            let worker = BackgroundWorker(mode: .backgroundAppRefresh(identifier: self.identifier),
                                          flutterPluginRegistrantCallback: self.flutterPluginRegistrantCallback)

            worker.performBackgroundRequest { _ in
                semaphore.signal()
            }
        }
        // timeout after 29seconds ,max execution time is 30seconds
        // -> 1 second for dispatching and other stuff (Flutter Messenger etc)
        let dispatchResult = semaphore.wait(timeout: DispatchTime.now()+29)

        print("handleAppRefresh \(dispatchResult)")
        debugHelper.showCompletedBGRefreshNotification(
            completedDate: Date(),
            result: dispatchResult == .timedOut ? .failed : .newData,
            elapsedTime: Date().timeIntervalSince(taskSessionStart))

    }

    /// register names for BGProcessingTask called by workmanger.m
    /// you must register tasknames before app finishes launching in appdelegate --> else there is an error thrown
    @objc
    public static func registerBackgroundProcessingTask(taskIdentifier identifier: String) {
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
            }}}

    @objc
    public static func registerBackgroundProcessingTaskScheduler(withIdentifier identifier: String,
                                                                 earliestBeginInSeconds begin: Double,
                                                                 requiresNetworkConnectivity: Bool,
                                                                 requiresExternalPower: Bool) {
        if #available(iOS 13.0, *) {
            print("Workmanager - registerBackgroundProcessingTaskScheduler withIdentifier \(identifier)")
            scheduleBackgroundProcessingTask(withIdentifier: identifier,
                                             earliestBeginInSeconds: begin,
                                             requiresNetworkConnectivity: requiresNetworkConnectivity,
                                             requiresExternalPower: requiresExternalPower)
        }
    }

    @objc
    public static func registerAppRefreshTaskScheduler(
        withIdentifier identifier: String,
        earliestBeginInSeconds begin: Double) {
            if #available(iOS 13.0, *) {
                print("Workmanager - registerAppRefreshTaskScheduler withIdentifier \(identifier)")
                // schedule on app did enter background
                NotificationCenter.default.addObserver(
                    forName: UIApplication.didEnterBackgroundNotification,
                    object: nil, queue: nil
                ) { (_) in
                    // schedule apprefresh
                    scheduleAppRefresh(withIdentifier: identifier, earliestBeginInSeconds: begin)
                }
            }
        }

    static func callback(_: UIBackgroundFetchResult) {
    }

    @objc
    @available(iOS 13.0, *)
    private static func scheduleAppRefresh(withIdentifier identifier: String, earliestBeginInSeconds begin: Double) {

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

    @objc
    @available(iOS 13.0, *)
    private static func scheduleBackgroundProcessingTask(
        withIdentifier identifier: String,
        earliestBeginInSeconds begin: Double,
        requiresNetworkConnectivity: Bool,
        requiresExternalPower: Bool
    ) {
        let request = BGProcessingTaskRequest(
            identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: begin)
        request.requiresNetworkConnectivity = requiresNetworkConnectivity
        request.requiresExternalPower = requiresExternalPower
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Requested BackgroundProcessingTask  \(identifier)")
        } catch {
            print("Couldn't schedule app BackgroundProcessingTask identifier:\(identifier) error:\(error.localizedDescription)")
            print("On BGTaskSchedulerErrorDomain error 1 - please run on real device")
            print("On BGTaskSchedulerErrorDomain error 3 - check registered names")
        }
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
            _=checkBackgroundRefreshAuthorisation(result: result)
            return
        case (ForegroundMethodChannel.Methods.RegisterPeriodicTask.name, let .some(arguments)):
            // register bgAppRefreshTask for less than 30 seconds backgroundtime
            registerPeriodicTask(arguments: arguments, result: result)
            return
        case (ForegroundMethodChannel.Methods.RegisterOneOffTask.name, let .some(arguments)):
            // register processingtask for more than 30 seconds backgroundtime
            registerOneOffTask(arguments: arguments, result: result)
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
            guard let identifier =
                    arguments[method.Arguments.uniqueName.rawValue] as? String else {
                result(WMPError.invalidParameters.asFlutterError)
                return
            }
            guard let initialDelaySeconds =
                    arguments[method.Arguments.initialDelaySeconds.rawValue] as? Int64 else {
                result(WMPError.invalidParameters.asFlutterError)
                return
            }
            // task will scheduled when app goes to background
            SwiftWorkmanagerPlugin.registerAppRefreshTaskScheduler(
                withIdentifier: identifier,
                earliestBeginInSeconds: Double(initialDelaySeconds))
            print("Registered PeriodicTask \(identifier) delaySeconds \(initialDelaySeconds)")
            result(true)
            return
        } else {
            result(FlutterError(code: "99",
                                message: "RegisterPeriodicTask is not registered",
                                details: "iOS Version lower than 13.0"))
        }
    }

    private func registerOneOffTask(arguments: [AnyHashable: Any], result: @escaping FlutterResult) {
        print("Registering OneOffTask  (BackgroundProcessingTask)")
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
            guard let identifier =
                    arguments[method.Arguments.uniqueName.rawValue] as? String else {
                result(WMPError.invalidParameters.asFlutterError)
                return
            }
            let requiresCharging = arguments[method.Arguments.requiresCharging.rawValue] as? Bool ?? false
            var requiresNetwork = false
            if let networkTypeInput = arguments[method.Arguments.networkType.rawValue] as? String,
               let networkType = NetworkType(fromDart: networkTypeInput),
               networkType == .connected || networkType == .metered {
                requiresNetwork = true
            }
            // task will scheduled when app goes to background
            SwiftWorkmanagerPlugin.registerBackgroundProcessingTaskScheduler(
                withIdentifier: identifier,
                earliestBeginInSeconds: Double(delaySeconds),
                requiresNetworkConnectivity: requiresCharging,
                requiresExternalPower: requiresNetwork)
            result(true)
            return
        } else {
            result(FlutterError(code: "99",
                                message: "RegisterPeriodicTask is not registered",
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
        return  true
    }
}

// MARK: - AppDelegate conformance

extension SwiftWorkmanagerPlugin {

    override public func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) -> Bool {
        let worker = BackgroundWorker(
            mode: .backgroundFetch,
            flutterPluginRegistrantCallback: SwiftWorkmanagerPlugin.flutterPluginRegistrantCallback
        )
        return worker.performBackgroundRequest(completionHandler)
    }
}
