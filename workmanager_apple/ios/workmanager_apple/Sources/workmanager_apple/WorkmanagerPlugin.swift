import Foundation
import os

#if os(iOS)
import BackgroundTasks
import Flutter
import UIKit
#elseif os(macOS)
import FlutterMacOS
#else
#error("Unsupported platform.")
#endif

/**
 * Pigeon-based implementation of WorkmanagerHostApi for iOS and macOS.
 * Replaces the manual method channel and data extraction approach.
 *
 * - iOS uses BGTaskScheduler (BGAppRefreshTask / BGProcessingTask).
 * - macOS uses NSBackgroundActivityScheduler (see MacOSActivityScheduler),
 *   the equivalent API for macOS.
 *
 * Note: Pigeon guarantees that host API handlers are not called when the plugin
 * is detached, so properties can be safely used without null checks in API methods.
 */
#if os(iOS)
public typealias WorkmanagerPluginBase = FlutterPluginAppLifeCycleDelegate
#elseif os(macOS)
public typealias WorkmanagerPluginBase = NSObject
#else
#error("Unsupported platform.")
#endif

public class WorkmanagerPlugin: WorkmanagerPluginBase, FlutterPlugin, WorkmanagerHostApi {
    static let identifier = "dev.fluttercommunity.workmanager"

    private static var flutterPluginRegistrantCallback: WMPFlutterPluginRegistrantCallback?

    /// Sets the plugin registrant callback for background task execution.
    ///
    /// This callback is used to register additional plugins when background tasks
    /// run in a separate Flutter engine instance.
    ///
    /// - Parameter callback: The callback to register plugins in the background engine
    #if os(iOS)
    @objc
    public static func setPluginRegistrantCallback(_ callback: @escaping FlutterPluginRegistrantCallback) {
        flutterPluginRegistrantCallback = callback
    }
    #elseif os(macOS)
    /// macOS has no `FlutterPluginRegistrantCallback` typealias; the app wires the
    /// generated registrant (e.g. `RegisterGeneratedPlugins(registry:)`) through a
    /// closure that receives the headless engine's plugin registry.
    public static func setPluginRegistrantCallback(_ callback: @escaping (FlutterPluginRegistry) -> Void) {
        flutterPluginRegistrantCallback = callback
    }
    #endif

    // MARK: - WorkmanagerHostApi implementation (shared)

    func initialize(request: InitializeRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        UserDefaultsHelper.storeCallbackHandle(request.callbackHandle)
        completion(.success(()))
    }

    func cancelByTag(tag: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Tags are not supported on iOS/macOS - this is an Android-specific feature
        completion(.success(()))
    }

    // MARK: - WorkmanagerHostApi implementation (iOS)

    #if os(iOS)
    func registerOneOffTask(request: OneOffTaskRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        guard validateCallbackHandle() else {
            completion(.failure(createInitializationError()))
            return
        }

        executeIfSupportedVoid(completion: completion, feature: "OneOffTask") {
            var taskIdentifier: UIBackgroundTaskIdentifier = .invalid
            let delaySeconds = request.initialDelaySeconds ?? 0

            taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: request.uniqueName, expirationHandler: {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
            })

            WorkmanagerPlugin.startOneOffTask(
                // The callback task name must match the `taskName` provided from Dart
                // (Android already forwards `taskName`). The `uniqueName` is still
                // used for the background task debug name above.
                identifier: request.taskName,
                taskIdentifier: taskIdentifier,
                inputData: request.inputData as? [String: Any],
                delaySeconds: delaySeconds
            )

            let taskInfo = TaskDebugInfo(
                taskName: request.taskName,
                uniqueName: request.uniqueName,
                inputData: request.inputData as? [String: Any],
                startTime: Date().timeIntervalSince1970
            )
            WorkmanagerDebug.getCurrent().onTaskStatusUpdate(taskInfo: taskInfo, status: .scheduled, result: nil)
        }
    }

    func registerPeriodicTask(request: PeriodicTaskRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        guard validateCallbackHandle() else {
            completion(.failure(createInitializationError()))
            return
        }

        executeIfSupportedVoid(completion: completion, feature: "PeriodicTask") {
            let initialDelaySeconds = Double(request.initialDelaySeconds ?? 0)

            // Store the inputData for later retrieval when the task executes
            UserDefaultsHelper.storePeriodicTaskInputData(
                request.inputData as? [String: Any],
                forTaskIdentifier: request.uniqueName
            )

            WorkmanagerPlugin.schedulePeriodicTask(
                taskIdentifier: request.uniqueName,
                earliestBeginInSeconds: initialDelaySeconds
            )

            let taskInfo = TaskDebugInfo(
                taskName: request.taskName,
                uniqueName: request.uniqueName,
                inputData: request.inputData as? [String: Any],
                startTime: Date().timeIntervalSince1970
            )
            WorkmanagerDebug.getCurrent().onTaskStatusUpdate(taskInfo: taskInfo, status: .scheduled, result: nil)
        }
    }

    func registerProcessingTask(request: ProcessingTaskRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        guard validateCallbackHandle() else {
            completion(.failure(createInitializationError()))
            return
        }

        executeIfSupportedVoid(completion: completion, feature: "BackgroundProcessingTask") {
            let delaySeconds = Double(request.initialDelaySeconds ?? 0)
            let requiresCharging = request.requiresCharging ?? false
            let requiresNetwork = request.networkType == .connected || request.networkType == .metered

            WorkmanagerPlugin.scheduleBackgroundProcessingTask(
                withIdentifier: request.uniqueName,
                earliestBeginInSeconds: delaySeconds,
                requiresNetworkConnectivity: requiresNetwork,
                requiresExternalPower: requiresCharging
            )
        }
    }

    func registerHealthResearchTask(
        request: HealthResearchTaskRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard validateCallbackHandle() else {
            completion(.failure(createInitializationError()))
            return
        }

        guard #available(iOS 17.0, *) else {
            completion(.failure(PigeonError(
                code: "99",
                message: "HealthResearchTask could not be registered",
                details: "BGHealthResearchTaskRequest is only supported on iOS 17+"
            )))
            return
        }

        let delaySeconds = Double(request.initialDelaySeconds ?? 0)
        let requiresCharging = request.requiresCharging ?? false
        let requiresNetwork = request.networkType == .connected || request.networkType == .metered

        // Reuse the periodic inputData storage (keyed by task identifier) so
        // the task receives the payload captured at registration time.
        UserDefaultsHelper.storePeriodicTaskInputData(
            request.inputData as? [String: Any],
            forTaskIdentifier: request.uniqueName
        )

        WorkmanagerPlugin.scheduleHealthResearchTask(
            withIdentifier: request.uniqueName,
            earliestBeginInSeconds: delaySeconds,
            requiresNetworkConnectivity: requiresNetwork,
            requiresExternalPower: requiresCharging
        )
        completion(.success(()))
    }

    func cancelByUniqueName(uniqueName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        executeIfSupportedVoid(completion: completion, feature: "cancelByUniqueName") {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: uniqueName)
            UserDefaultsHelper.removeScheduledTask(uniqueName)
        }
    }

    func cancelAll(completion: @escaping (Result<Void, Error>) -> Void) {
        executeIfSupportedVoid(completion: completion, feature: "cancelAll") {
            BGTaskScheduler.shared.cancelAllTaskRequests()
            UserDefaultsHelper.removeAllScheduledTasks()
        }
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
    #endif

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

// MARK: - WorkmanagerHostApi implementation (macOS)

#if os(macOS)
extension WorkmanagerPlugin {
    func registerOneOffTask(request: OneOffTaskRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        guard validateCallbackHandle() else {
            completion(.failure(createInitializationError()))
            return
        }

        let delaySeconds = Double(request.initialDelaySeconds ?? 0)
        if delaySeconds > 0 {
            MacOSActivityScheduler.shared.scheduleActivity(
                uniqueName: request.uniqueName,
                isPeriodic: false,
                interval: delaySeconds,
                inputData: request.inputData as? [String: Any],
                flutterPluginRegistrantCallback: WorkmanagerPlugin.flutterPluginRegistrantCallback
            )
        } else {
            MacOSActivityScheduler.shared.runOneOffTaskNow(
                uniqueName: request.uniqueName,
                taskName: request.taskName,
                inputData: request.inputData as? [String: Any],
                flutterPluginRegistrantCallback: WorkmanagerPlugin.flutterPluginRegistrantCallback
            )
        }

        let taskInfo = TaskDebugInfo(
            taskName: request.taskName,
            uniqueName: request.uniqueName,
            inputData: request.inputData as? [String: Any],
            startTime: Date().timeIntervalSince1970
        )
        WorkmanagerDebug.getCurrent().onTaskStatusUpdate(taskInfo: taskInfo, status: .scheduled, result: nil)
        completion(.success(()))
    }

    func registerPeriodicTask(request: PeriodicTaskRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        guard validateCallbackHandle() else {
            completion(.failure(createInitializationError()))
            return
        }

        let frequencySeconds = max(Double(request.frequencySeconds), 1)
        MacOSActivityScheduler.shared.scheduleActivity(
            uniqueName: request.uniqueName,
            isPeriodic: true,
            interval: frequencySeconds,
            inputData: request.inputData as? [String: Any],
            flutterPluginRegistrantCallback: WorkmanagerPlugin.flutterPluginRegistrantCallback
        )

        let taskInfo = TaskDebugInfo(
            taskName: request.taskName,
            uniqueName: request.uniqueName,
            inputData: request.inputData as? [String: Any],
            startTime: Date().timeIntervalSince1970
        )
        WorkmanagerDebug.getCurrent().onTaskStatusUpdate(taskInfo: taskInfo, status: .scheduled, result: nil)
        completion(.success(()))
    }

    func registerProcessingTask(request: ProcessingTaskRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        guard validateCallbackHandle() else {
            completion(.failure(createInitializationError()))
            return
        }

        // NSBackgroundActivityScheduler has no network/charging constraints;
        // processing tasks map to a one-off task scheduled best-effort.
        let delaySeconds = Double(request.initialDelaySeconds ?? 0)
        if delaySeconds > 0 {
            MacOSActivityScheduler.shared.scheduleActivity(
                uniqueName: request.uniqueName,
                isPeriodic: false,
                interval: delaySeconds,
                inputData: request.inputData as? [String: Any],
                flutterPluginRegistrantCallback: WorkmanagerPlugin.flutterPluginRegistrantCallback
            )
        } else {
            MacOSActivityScheduler.shared.runOneOffTaskNow(
                uniqueName: request.uniqueName,
                taskName: request.taskName,
                inputData: request.inputData as? [String: Any],
                flutterPluginRegistrantCallback: WorkmanagerPlugin.flutterPluginRegistrantCallback
            )
        }

        let taskInfo = TaskDebugInfo(
            taskName: request.taskName,
            uniqueName: request.uniqueName,
            inputData: request.inputData as? [String: Any],
            startTime: Date().timeIntervalSince1970
        )
        WorkmanagerDebug.getCurrent().onTaskStatusUpdate(taskInfo: taskInfo, status: .scheduled, result: nil)
        completion(.success(()))
    }

    func registerHealthResearchTask(
        request: HealthResearchTaskRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // BGHealthResearchTaskRequest is iOS 17+-only and requires the health
        // research study entitlement; it is not available on macOS.
        completion(.failure(PigeonError(
            code: "99",
            message: "HealthResearchTask could not be registered",
            details: "BGHealthResearchTaskRequest is only supported on iOS 17+"
        )))
    }

    func cancelByUniqueName(uniqueName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        MacOSActivityScheduler.shared.cancel(uniqueName: uniqueName)
        completion(.success(()))
    }

    func cancelAll(completion: @escaping (Result<Void, Error>) -> Void) {
        MacOSActivityScheduler.shared.cancelAll()
        completion(.success(()))
    }

    func isScheduledByUniqueName(uniqueName: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(MacOSActivityScheduler.shared.isScheduled(uniqueName: uniqueName)))
    }

    func printScheduledTasks(completion: @escaping (Result<String, Error>) -> Void) {
        completion(.success(MacOSActivityScheduler.shared.printScheduledActivities()))
    }
}
#endif

// MARK: - Background task scheduling (iOS only)

#if os(iOS)
extension WorkmanagerPlugin {
    /// Identifiers whose launch handler has already been registered in this
    /// process. BGTaskScheduler rejects a second registration for the same
    /// identifier, so this guards the submit-time and launch-time paths (and
    /// user AppDelegate registrations) against double registration.
    private static var registeredLaunchHandlers: Set<String> = []

    @available(iOS 13.0, *)
    private static func handleBGProcessingTask(identifier: String, task: BGProcessingTask) {
        let operationQueue = OperationQueue()
        let operation = createBackgroundOperation(
            identifier: task.identifier,
            inputData: nil,
            backgroundMode: .backgroundProcessingTask(identifier: identifier)
        )

        task.expirationHandler = { operation.cancel() }
        operation.completionBlock = { task.setTaskCompleted(success: !operation.isCancelled) }

        operationQueue.addOperation(operation)
    }

    /// Handles execution of a periodic background task.
    ///
    /// This method is called by iOS when a BGAppRefreshTask is triggered.
    /// It retrieves stored inputData and executes the Flutter task.
    ///
    /// - Parameters:
    ///   - identifier: Task identifier
    ///   - task: The BGAppRefreshTask instance from iOS
    ///   - earliestBeginInSeconds: Optional delay before scheduling next occurrence
    ///   - inputData: Input data passed from the Dart side (may be nil)
    @available(iOS 13.0, *)
    public static func handlePeriodicTask(identifier: String, task: BGAppRefreshTask, earliestBeginInSeconds: NSNumber?, inputData: [String: Any]?) {
        guard let callbackHandle = UserDefaultsHelper.getStoredCallbackHandle(),
              let _ = FlutterCallbackCache.lookupCallbackInformation(callbackHandle)
        else {
            logError("[\(String(describing: self))] \(WMPError.workmanagerNotInitialized.message)")
            return
        }

        // Schedule the next occurrence (iOS will determine actual timing based on usage patterns)
        schedulePeriodicTask(taskIdentifier: task.identifier, earliestBeginInSeconds: earliestBeginInSeconds?.doubleValue)

        // Execute the Flutter task directly
        let worker = BackgroundWorker(
            mode: .backgroundPeriodicTask(identifier: identifier),
            inputData: inputData,
            flutterPluginRegistrantCallback: flutterPluginRegistrantCallback
        )

        // Set up expiration handler
        task.expirationHandler = {
            logInfo("BGAppRefreshTask expired: \(identifier)")
        }

        // Execute on main thread (required for Flutter)
        DispatchQueue.main.async {
            worker.performBackgroundRequest { result in
                task.setTaskCompleted(success: result == .newData)
            }
        }
    }

    /// Starts a one-off background task with the specified input data.
    ///
    /// - Parameters:
    ///   - identifier: Task identifier
    ///   - taskIdentifier: iOS background task identifier for lifecycle management
    ///   - inputData: Input data to pass to the Flutter task
    ///   - delaySeconds: Delay before task execution
    @available(iOS 13.0, *)
    public static func startOneOffTask(identifier: String, taskIdentifier: UIBackgroundTaskIdentifier, inputData: [String: Any]?, delaySeconds: Int64) {
        let operationQueue = OperationQueue()
        let operation = createBackgroundOperation(
            identifier: identifier,
            inputData: inputData,
            backgroundMode: .backgroundOneOffTask(identifier: identifier)
        )

        operation.completionBlock = { UIApplication.shared.endBackgroundTask(taskIdentifier) }
        if delaySeconds > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(delaySeconds)) {
                operationQueue.addOperation(operation)
            }
        } else {
            operationQueue.addOperation(operation)
        }
    }

    /// Registers a periodic background task with iOS BGTaskScheduler.
    ///
    /// This method must be called during app initialization (typically in AppDelegate)
    /// to register the task identifier with iOS. The actual task scheduling with inputData
    /// happens later when called from the Dart/Flutter side.
    ///
    /// - Parameters:
    ///   - identifier: Unique task identifier that matches the one used in Dart
    ///   - earliestBeginInSeconds: Optional delay before scheduling next occurrence
    ///
    /// - Note: This registers the task handler only. Use Workmanager.registerPeriodicTask()
    ///   from Dart to actually schedule the task with inputData.
    @objc
    public static func registerPeriodicTask(withIdentifier identifier: String, earliestBeginInSeconds: NSNumber? = nil) {
        if #available(iOS 13.0, *) {
            UserDefaultsHelper.storeScheduledTask(
                ScheduledTaskInfo(kind: .refresh, earliestBeginInSeconds: earliestBeginInSeconds?.doubleValue),
                forTaskIdentifier: identifier
            )
            registerLaunchHandlerOnce(forTaskWithIdentifier: identifier, earliestBeginInSeconds: earliestBeginInSeconds)
        }
    }

    /// Registers a periodic background task with iOS BGTaskScheduler.
    ///
    /// - Parameters:
    ///   - identifier: Unique task identifier that matches the one used in Dart
    ///   - frequency: Frequency hint in seconds (deprecated, use earliestBeginInSeconds instead)
    ///
    /// - Note: Deprecated. Use registerPeriodicTask(withIdentifier:earliestBeginInSeconds:) instead.
    @available(*, deprecated, message: "Use registerPeriodicTask(withIdentifier:earliestBeginInSeconds:) instead")
    @objc
    public static func registerPeriodicTask(withIdentifier identifier: String, frequency: NSNumber?) {
        registerPeriodicTask(withIdentifier: identifier, earliestBeginInSeconds: frequency)
    }

    @available(iOS 13.0, *)
    private static func schedulePeriodicTask(taskIdentifier identifier: String, earliestBeginInSeconds begin: Double?) {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        if let begin = begin {
            request.earliestBeginDate = Date(timeIntervalSinceNow: begin)
        }
        do {
            try BGTaskScheduler.shared.submit(request)
            logInfo("BGAppRefreshTask submitted \(identifier) earliestBeginInSeconds:\(String(describing: begin))")
            UserDefaultsHelper.storeScheduledTask(
                ScheduledTaskInfo(kind: .refresh, earliestBeginInSeconds: begin),
                forTaskIdentifier: identifier
            )
            registerLaunchHandlerOnce(
                forTaskWithIdentifier: identifier,
                earliestBeginInSeconds: begin.map { NSNumber(value: $0) }
            )
        } catch {
            logInfo("Could not schedule BGAppRefreshTask \(error.localizedDescription)")
        }
    }

    /// Registers a background processing task with iOS BGTaskScheduler.
    ///
    /// This method must be called during app initialization (typically in AppDelegate)
    /// to register the task identifier with iOS for background processing tasks.
    ///
    /// - Parameter identifier: Unique task identifier that matches the one used in Dart
    @objc
    public static func registerBGProcessingTask(withIdentifier identifier: String) {
        if #available(iOS 13.0, *) {
            UserDefaultsHelper.storeScheduledTask(
                ScheduledTaskInfo(kind: .processing, earliestBeginInSeconds: nil),
                forTaskIdentifier: identifier
            )
            registerLaunchHandlerOnce(forTaskWithIdentifier: identifier, earliestBeginInSeconds: nil)
        }
    }

    /// Registers a health research task with iOS BGTaskScheduler.
    ///
    /// Health research tasks are delivered to apps participating in a Health
    /// Research Study container (iOS 17+) with the
    /// `com.apple.developer.backgroundtasks.healthresearch` entitlement, where
    /// the user has opted in to the study. The identifier must also be listed
    /// in `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
    ///
    /// - Parameter identifier: Unique task identifier that matches the one used in Dart
    @objc
    public static func registerBGHealthResearchTask(withIdentifier identifier: String) {
        guard #available(iOS 17.0, *) else {
            return
        }
        UserDefaultsHelper.storeScheduledTask(
            ScheduledTaskInfo(kind: .healthResearch, earliestBeginInSeconds: nil),
            forTaskIdentifier: identifier
        )
        registerLaunchHandlerOnce(forTaskWithIdentifier: identifier, earliestBeginInSeconds: nil)
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
            UserDefaultsHelper.storeScheduledTask(
                ScheduledTaskInfo(kind: .processing, earliestBeginInSeconds: begin),
                forTaskIdentifier: uniqueTaskIdentifier
            )
            registerLaunchHandlerOnce(forTaskWithIdentifier: uniqueTaskIdentifier, earliestBeginInSeconds: nil)
        } catch {
            logInfo("Could not schedule BGProcessingTask identifier:\(uniqueTaskIdentifier) error:\(error.localizedDescription)")
            logInfo("Possible issues can be: running on a simulator instead of a real device, or the task name is not registered")
        }
    }

    /// Handles execution of a health research background task.
    ///
    /// BGHealthResearchTask is a subclass of BGProcessingTask: the task can
    /// run for minutes while the device is idle, but the system can still
    /// interrupt it (the expiration handler cancels the operation).
    @available(iOS 17.0, *)
    private static func handleBGHealthResearchTask(identifier: String, task: BGHealthResearchTask) {
        let operationQueue = OperationQueue()
        // Deliver the inputData stored at registration time (mirroring the
        // periodic task path, keyed by task identifier).
        let storedInputData = UserDefaultsHelper.getStoredPeriodicTaskInputData(forTaskIdentifier: task.identifier)
        let operation = createBackgroundOperation(
            identifier: task.identifier,
            inputData: storedInputData,
            backgroundMode: .backgroundHealthResearchTask(identifier: identifier)
        )

        task.expirationHandler = { operation.cancel() }
        operation.completionBlock = { task.setTaskCompleted(success: !operation.isCancelled) }

        operationQueue.addOperation(operation)
    }

    @available(iOS 17.0, *)
    private static func scheduleHealthResearchTask(
        withIdentifier uniqueTaskIdentifier: String,
        earliestBeginInSeconds begin: Double,
        requiresNetworkConnectivity: Bool,
        requiresExternalPower: Bool
    ) {
        let request = BGHealthResearchTaskRequest(identifier: uniqueTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: begin)
        request.requiresNetworkConnectivity = requiresNetworkConnectivity
        request.requiresExternalPower = requiresExternalPower

        do {
            try BGTaskScheduler.shared.submit(request)
            logInfo("BGHealthResearchTask submitted \(uniqueTaskIdentifier) earliestBeginInSeconds:\(begin)")
            UserDefaultsHelper.storeScheduledTask(
                ScheduledTaskInfo(kind: .healthResearch, earliestBeginInSeconds: begin),
                forTaskIdentifier: uniqueTaskIdentifier
            )
            registerLaunchHandlerOnce(forTaskWithIdentifier: uniqueTaskIdentifier, earliestBeginInSeconds: nil)
        } catch {
            logInfo("Could not schedule BGHealthResearchTask identifier:\(uniqueTaskIdentifier) error:\(error.localizedDescription)")
            logInfo("Possible issues: iOS 17+ required, or the app is missing the health research study entitlement / the user has not opted in")
        }
    }

    /// Registers the launch handler for [identifier] at most once per process.
    ///
    /// The handler dispatches on the delivered task type so periodic
    /// (BGAppRefreshTask), processing (BGProcessingTask) and health research
    /// (BGHealthResearchTask) identifiers can be re-registered from persisted
    /// state at app launch.
    @available(iOS 13.0, *)
    private static func registerLaunchHandlerOnce(
        forTaskWithIdentifier identifier: String,
        earliestBeginInSeconds: NSNumber?
    ) {
        guard !registeredLaunchHandlers.contains(identifier) else {
            return
        }
        registeredLaunchHandlers.insert(identifier)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier,
            using: nil
        ) { task in
            if let task = task as? BGAppRefreshTask {
                // Retrieve the stored inputData for this periodic task
                let storedInputData = UserDefaultsHelper.getStoredPeriodicTaskInputData(forTaskIdentifier: task.identifier)
                handlePeriodicTask(
                    identifier: identifier,
                    task: task,
                    earliestBeginInSeconds: earliestBeginInSeconds,
                    inputData: storedInputData
                )
            } else if #available(iOS 17.0, *), let task = task as? BGHealthResearchTask {
                // BGHealthResearchTask is a subclass of BGProcessingTask, so it
                // must be checked before the generic BGProcessingTask branch.
                handleBGHealthResearchTask(identifier: identifier, task: task)
            } else if let task = task as? BGProcessingTask {
                handleBGProcessingTask(identifier: identifier, task: task)
            }
        }
    }

    private func createUnsupportedVersionError(feature: String) -> PigeonError {
        return PigeonError(
            code: "99",
            message: "\(feature) could not be registered",
            details: "BGTaskScheduler tasks are only supported on iOS 13+"
        )
    }

    private func executeIfSupported<T>(
        completion: @escaping (Result<T, Error>) -> Void,
        defaultValue: T? = nil,
        feature: String,
        action: @escaping () -> T
    ) {
        if #available(iOS 13.0, *) {
            let result = action()
            completion(.success(result))
        } else {
            if let defaultValue = defaultValue {
                completion(.success(defaultValue))
            } else {
                completion(.failure(createUnsupportedVersionError(feature: feature)))
            }
        }
    }

    private func executeIfSupportedVoid(
        completion: @escaping (Result<Void, Error>) -> Void,
        feature: String,
        action: @escaping () -> Void
    ) {
        if #available(iOS 13.0, *) {
            action()
            completion(.success(()))
        } else {
            completion(.failure(createUnsupportedVersionError(feature: feature)))
        }
    }

    @available(iOS 13.0, *)
    private static func createBackgroundOperation(
        identifier: String,
        inputData: [String: Any]?,
        backgroundMode: BackgroundMode
    ) -> BackgroundTaskOperation {
        return BackgroundTaskOperation(
            identifier,
            inputData: inputData,
            flutterPluginRegistrantCallback: flutterPluginRegistrantCallback,
            backgroundMode: backgroundMode
        )
    }
}
#endif

// MARK: - FlutterPlugin conformance

extension WorkmanagerPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = WorkmanagerPlugin()
        #if os(iOS)
        WorkmanagerHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
        registrar.addApplicationDelegate(instance)
        #elseif os(macOS)
        WorkmanagerHostApiSetup.setUp(binaryMessenger: registrar.messenger, api: instance)
        #endif
    }
}

// MARK: - AppDelegate conformance (iOS only)

#if os(iOS)
extension WorkmanagerPlugin {
    override public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [AnyHashable: Any]? = nil
    ) -> Bool {
        // BGTaskScheduler only delivers a task to a relaunched app if a launch
        // handler was registered during `didFinishLaunching`. Re-register the
        // handlers for identifiers scheduled in previous sessions, so periodic
        // and processing tasks keep working without manual AppDelegate code.
        if #available(iOS 13.0, *) {
            for (identifier, info) in UserDefaultsHelper.getScheduledTasks() {
                WorkmanagerPlugin.registerLaunchHandlerOnce(
                    forTaskWithIdentifier: identifier,
                    earliestBeginInSeconds: info.earliestBeginInSeconds.map { NSNumber(value: $0) }
                )
            }
        }
        return true
    }

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

        return worker.performBackgroundRequest { result in
            completionHandler(result == .newData ? .newData : .failed)
        }
    }
}
#endif
