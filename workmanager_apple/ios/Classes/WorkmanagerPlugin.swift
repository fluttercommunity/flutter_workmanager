import BackgroundTasks
import Flutter
import UIKit
import os

/**
 * Pigeon-based implementation of WorkmanagerHostApi for iOS.
 * Replaces the manual method channel and data extraction approach.
 * 
 * Note: Pigeon guarantees that host API handlers are not called when the plugin
 * is detached, so properties can be safely used without null checks in API methods.
 */
public class WorkmanagerPlugin: FlutterPluginAppLifeCycleDelegate, FlutterPlugin, WorkmanagerHostApi {
    static let identifier = "dev.fluttercommunity.workmanager"
    
    private static var flutterPluginRegistrantCallback: FlutterPluginRegistrantCallback?
    private var isInDebugMode: Bool = false
    
    // MARK: - Static Background Task Handlers
    
    @available(iOS 13.0, *)
    private static func handleBGProcessingTask(identifier: String, task: BGProcessingTask) {
        let operationQueue = OperationQueue()
        
        let operation = BackgroundTaskOperation(
            task.identifier,
            inputData: nil,
            flutterPluginRegistrantCallback: flutterPluginRegistrantCallback,
            backgroundMode: .backgroundProcessingTask(identifier: identifier)
        )
        
        task.expirationHandler = {
            operation.cancel()
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }
        
        operationQueue.addOperation(operation)
    }
    
    @available(iOS 13.0, *)
    public static func handlePeriodicTask(identifier: String, task: BGAppRefreshTask, earliestBeginInSeconds: Double?) {
        guard let callbackHandle = UserDefaultsHelper.getStoredCallbackHandle(),
              let _ = FlutterCallbackCache.lookupCallbackInformation(callbackHandle)
        else {
            logError("[\(String(describing: self))] \(WMPError.workmanagerNotInitialized.message)")
            return
        }
        
        // If frequency is not provided it will default to 15 minutes
        schedulePeriodicTask(taskIdentifier: task.identifier, earliestBeginInSeconds: earliestBeginInSeconds ?? (15 * 60))
        
        let operationQueue = OperationQueue()
        let operation = BackgroundTaskOperation(
            task.identifier,
            inputData: nil,
            flutterPluginRegistrantCallback: flutterPluginRegistrantCallback,
            backgroundMode: .backgroundPeriodicTask(identifier: identifier)
        )
        
        task.expirationHandler = {
            operation.cancel()
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }
        
        operationQueue.addOperation(operation)
    }
    
    @available(iOS 13.0, *)
    public static func startOneOffTask(identifier: String, taskIdentifier: UIBackgroundTaskIdentifier, inputData: [String: Any]?, delaySeconds: Int64) {
        let operationQueue = OperationQueue()
        let operation = BackgroundTaskOperation(
            identifier,
            inputData: inputData,
            flutterPluginRegistrantCallback: flutterPluginRegistrantCallback,
            backgroundMode: .backgroundOneOffTask(identifier: identifier)
        )
        
        operation.completionBlock = {
            UIApplication.shared.endBackgroundTask(taskIdentifier)
        }
        
        operationQueue.addOperation(operation)
    }
    
    @objc
    public static func registerPeriodicTask(withIdentifier identifier: String, frequency: NSNumber?) {
        if #available(iOS 13.0, *) {
            var frequencyInSeconds: Double?
            if let frequencyValue = frequency {
                frequencyInSeconds = frequencyValue.doubleValue
            }
            
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: identifier,
                using: nil
            ) { task in
                if let task = task as? BGAppRefreshTask {
                    handlePeriodicTask(identifier: identifier, task: task, earliestBeginInSeconds: frequencyInSeconds)
                }
            }
        }
    }
    
    @objc
    @available(iOS 13.0, *)
    private static func schedulePeriodicTask(taskIdentifier identifier: String, earliestBeginInSeconds begin: Double) {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: begin)
        do {
            try BGTaskScheduler.shared.submit(request)
            logInfo("BGAppRefreshTask submitted \(identifier) earliestBeginInSeconds:\(begin)")
        } catch {
            logInfo("Could not schedule BGAppRefreshTask \(error.localizedDescription)")
        }
    }
    
    @objc
    public static func registerBGProcessingTask(withIdentifier identifier: String) {
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: identifier,
                using: nil
            ) { task in
                if let task = task as? BGProcessingTask {
                    handleBGProcessingTask(identifier: identifier, task: task)
                }
            }
        }
    }
    
    @objc
    @available(iOS 13.0, *)
    private static func scheduleBackgroundProcessingTask(
        withIdentifier uniqueTaskIdentifier: String,
        earliestBeginInSeconds begin: Double,
        requiresNetworkConnectivity: Bool,
        requiresExternalPower: Bool
    ) {
        let request = BGProcessingTaskRequest(identifier: uniqueTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: begin)
        request.requiresNetworkConnectivity = requiresNetworkConnectivity
        request.requiresExternalPower = requiresExternalPower
        do {
            try BGTaskScheduler.shared.submit(request)
            logInfo("BGProcessingTask submitted \(uniqueTaskIdentifier) earliestBeginInSeconds:\(begin)")
        } catch {
            logInfo("Could not schedule BGProcessingTask identifier:\(uniqueTaskIdentifier) error:\(error.localizedDescription)")
            logInfo("Possible issues can be: running on a simulator instead of a real device, or the task name is not registered")
        }
    }
    
    // MARK: - FlutterPlugin conformance
    
    @objc
    public static func setPluginRegistrantCallback(_ callback: @escaping FlutterPluginRegistrantCallback) {
        flutterPluginRegistrantCallback = callback
    }
    
    // MARK: - WorkmanagerHostApi implementation
    
    func initialize(request: InitializeRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        UserDefaultsHelper.storeCallbackHandle(request.callbackHandle)
        UserDefaultsHelper.storeIsDebug(request.isInDebugMode)
        isInDebugMode = request.isInDebugMode
        completion(.success(()))
    }
    
    func registerOneOffTask(request: OneOffTaskRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        guard validateCallbackHandle() else {
            completion(.failure(createInitializationError()))
            return
        }
        
        if #available(iOS 13.0, *) {
            var taskIdentifier: UIBackgroundTaskIdentifier = .invalid
            let delaySeconds = request.initialDelaySeconds ?? 0
            
            taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: request.uniqueName, expirationHandler: {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
            })
            
            WorkmanagerPlugin.startOneOffTask(
                identifier: request.uniqueName,
                taskIdentifier: taskIdentifier,
                inputData: request.inputData as? [String: Any],
                delaySeconds: delaySeconds
            )
            completion(.success(()))
        } else {
            completion(.failure(PigeonError(
                code: "99",
                message: "OneOffTask could not be registered",
                details: "BGTaskScheduler tasks are only supported on iOS 13+"
            )))
        }
    }
    
    func registerPeriodicTask(request: PeriodicTaskRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        guard validateCallbackHandle() else {
            completion(.failure(createInitializationError()))
            return
        }
        
        if #available(iOS 13.0, *) {
            let initialDelaySeconds = Double(request.initialDelaySeconds ?? 0)
            
            WorkmanagerPlugin.schedulePeriodicTask(
                taskIdentifier: request.uniqueName,
                earliestBeginInSeconds: initialDelaySeconds
            )
            completion(.success(()))
        } else {
            completion(.failure(PigeonError(
                code: "99", 
                message: "PeriodicTask could not be registered",
                details: "BGAppRefreshTasks are only supported on iOS 13+. Instead you should use Background Fetch"
            )))
        }
    }
    
    func registerProcessingTask(request: ProcessingTaskRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        guard validateCallbackHandle() else {
            completion(.failure(createInitializationError()))
            return
        }
        
        if #available(iOS 13.0, *) {
            let delaySeconds = Double(request.initialDelaySeconds ?? 0)
            let requiresCharging = request.requiresCharging ?? false
            
            var requiresNetwork = false
            if let networkType = request.networkType,
               networkType == .connected || networkType == .metered {
                requiresNetwork = true
            }
            
            WorkmanagerPlugin.scheduleBackgroundProcessingTask(
                withIdentifier: request.uniqueName,
                earliestBeginInSeconds: delaySeconds,
                requiresNetworkConnectivity: requiresNetwork,
                requiresExternalPower: requiresCharging
            )
            completion(.success(()))
        } else {
            completion(.failure(PigeonError(
                code: "99",
                message: "BackgroundProcessingTask could not be registered", 
                details: "BGProcessingTasks are only supported on iOS 13+"
            )))
        }
    }
    
    func cancelByUniqueName(uniqueName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: uniqueName)
        }
        completion(.success(()))
    }
    
    func cancelByTag(tag: String, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.failure(PigeonError(code: "not implemented", message: "not implemented", details: nil)))
    }
    
    func cancelAll(completion: @escaping (Result<Void, Error>) -> Void) {
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.cancelAllTaskRequests()
        }
        completion(.success(()))
    }
    
    func isScheduledByUniqueName(uniqueName: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.getPendingTaskRequests { taskRequests in
                let isScheduled = taskRequests.contains { $0.identifier == uniqueName }
                completion(.success(isScheduled))
            }
        } else {
            completion(.success(false))
        }
    }
    
    func printScheduledTasks(completion: @escaping (Result<String, Error>) -> Void) {
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.getPendingTaskRequests { taskRequests in
                if taskRequests.isEmpty {
                    let message = "[BGTaskScheduler] There are no scheduled tasks"
                    log(message)
                    completion(.success(message))
                    return
                }
                
                var message = "[BGTaskScheduler] Scheduled Tasks:"
                for taskRequest in taskRequests {
                    message += "\n[BGTaskScheduler] Task Identifier: \(taskRequest.identifier) earliestBeginDate: \(taskRequest.earliestBeginDate?.formatted() ?? "")"
                }
                log("\(message)")
                completion(.success(message))
            }
        } else {
            completion(.failure(PigeonError(
                code: "99",
                message: "printScheduledTasks is only supported on iOS 13+",
                details: "BGTaskScheduler.getPendingTaskRequests is only supported on iOS 13+"
            )))
        }
    }
    
    // MARK: - Helper methods
    
    private func validateCallbackHandle() -> Bool {
        return UserDefaultsHelper.getStoredCallbackHandle() != nil
    }
    
    private func createInitializationError() -> PigeonError {
        return PigeonError(
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
    }
}

// MARK: - FlutterPlugin conformance

extension WorkmanagerPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = WorkmanagerPlugin()
        WorkmanagerHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
        registrar.addApplicationDelegate(instance)
    }
}

// MARK: - AppDelegate conformance

extension WorkmanagerPlugin {
    override public func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) -> Bool {
        // Old background fetch API for iOS 12 and lower
        let worker = BackgroundWorker(
            mode: .backgroundFetch,
            inputData: nil,
            flutterPluginRegistrantCallback: WorkmanagerPlugin.flutterPluginRegistrantCallback
        )
        
        return worker.performBackgroundRequest(completionHandler)
    }
}
