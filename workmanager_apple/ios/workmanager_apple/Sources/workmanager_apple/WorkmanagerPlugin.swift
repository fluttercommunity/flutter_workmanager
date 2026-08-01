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
 * - macOS uses NSBackgroundActivityScheduler, the equivalent API for macOS.
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

#if os(iOS)
    private static var flutterPluginRegistrantCallback: WMPFlutterPluginRegistrantCallback?
#elseif os(macOS)
    private static var flutterPluginRegistrantCallback: WMPFlutterPluginRegistrantCallback?
#endif

    // MARK: - macOS NSBackgroundActivityScheduler

#if os(macOS)
    private static let activityRegistryLock = NSLock()
    private static var scheduledActivities: [String: NSBackgroundActivityScheduler] = [:]

    /// Schedules a task with NSBackgroundActivityScheduler.
    ///
    /// macOS has no BGTaskScheduler. `NSBackgroundActivityScheduler` runs the
    /// activity while the app process is alive (foreground or backgrounded) and
    /// the Mac is awake. Activities do not run after the app is quit.
    ///
    /// - Parameters:
    ///   - uniqueName: Unique task identifier (also used as the activity identifier).
    ///   - isPeriodic: `true` for repeating activities, `false` for one-off tasks.
    ///   - interval: For one-off tasks this is the delay before the run; for
    ///     periodic tasks it is the repeat interval in seconds.
    ///   - inputData: Input data passed from the Dart side.
    private static func scheduleActivity(
        uniqueName: String,
        isPeriodic: Bool,
        interval: TimeInterval,
        tolerance: TimeInterval?,
        inputData: [String: Any]?,
        taskName: String
    ) {
        let activity = NSBackgroundActivityScheduler(identifier: uniqueName)
        activity.repeats = isPeriodic
        activity.interval = interval
        if let tolerance = tolerance {
            activity.tolerance = tolerance
        }
        activity.qualityOfService = .utility

        activity.schedule { completion in
            logInfo("[NSBackgroundActivityScheduler] Activity fired: \(uniqueName)")

            let worker = BackgroundWorker(
                mode: isPeriodic
                    ? .backgroundPeriodicTask(identifier: uniqueName)
                    : .backgroundOneOffTask(identifier: uniqueName),
                inputData: inputData,
                flutterPluginRegistrantCallback: flutterPluginRegistrantCallback
            )

            // Flutter engine operations must happen on the main thread.
            DispatchQueue.main.async {
                worker.performBackgroundRequest { result in
                    logInfo(
                        "[NSBackgroundActivityScheduler] Activity \(uniqueName) finished with \(result.debugDescription)"
                    )
                    completion(.finished)
                }
            }
        }

        WorkmanagerPlugin.activityRegistryLock.lock()
        WorkmanagerPlugin.scheduledActivities[uniqueName]?.invalidate()
        WorkmanagerPlugin.scheduledActivities[uniqueName] = activity
        WorkmanagerPlugin.activityRegistryLock.unlock()

        logInfo(
            "[NSBackgroundActivityScheduler] Scheduled \(isPeriodic ? "periodic" : "one-off") activity " +
                "\(uniqueName) interval: \(interval)s"
        )
    }
#endif

    // MARK: - Static Background Task Handlers (iOS)

#if os(iOS)
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
        operationQueue.addOperation(operation)
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
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: identifier,
                using: nil
            ) { task in
                if let task = task as? BGAppRefreshTask {
                    // Retrieve the stored inputData for this periodic task
                    let storedInputData = UserDefaultsHelper.getStoredPeriodicTaskInputData(forTaskIdentifier: task.identifier)
                    handlePeriodicTask(identifier: identifier, task: task, earliestBeginInSeconds: earliestBeginInSeconds, inputData: storedInputData)
                }
            }
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
#endif

    // MARK: - FlutterPlugin conformance

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

    // MARK: - WorkmanagerHostApi implementation

    func initialize(request: InitializeRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        UserDefaultsHelper.storeCallbackHandle(request.callbackHandle)
        completion(.success(()))
    }

    func registerOneOffTask(request: OneOffTaskRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        guard validateCallbackHandle() else {
            completion(.failure(createInitializationError()))
            return
        }

        #if os(iOS)
        executeIfSupportedVoid(completion: completion, feature: "OneOffTask") {
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

            let taskInfo = TaskDebugInfo(
                taskName: request.taskName,
                uniqueName: request.uniqueName,
                inputData: request.inputData as? [String: Any],
                startTime: Date().timeIntervalSince1970
            )
            WorkmanagerDebug.getCurrent().onTaskStatusUpdate(taskInfo: taskInfo, status: .scheduled, result: nil)
        }
        #elseif os(macOS)
        let delaySeconds = Double(request.initialDelaySeconds ?? 0)

        WorkmanagerPlugin.scheduleActivity(
            uniqueName: request.uniqueName,
            isPeriodic: false,
            interval: delaySeconds,
            tolerance: 0,
            inputData: request.inputData as? [String: Any],
            taskName: request.taskName
        )

        let taskInfo = TaskDebugInfo(
            taskName: request.taskName,
            uniqueName: request.uniqueName,
            inputData: request.inputData as? [String: Any],
            startTime: Date().timeIntervalSince1970
        )
        WorkmanagerDebug.getCurrent().onTaskStatusUpdate(taskInfo: taskInfo, status: .scheduled, result: nil)
        completion(.success(()))
        #endif
    }

    func registerPeriodicTask(request: PeriodicTaskRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        guard validateCallbackHandle() else {
            completion(.failure(createInitializationError()))
            return
        }

        #if os(iOS)
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
        #elseif os(macOS)
        let frequencySeconds = max(Double(request.frequencySeconds), 1)

        WorkmanagerPlugin.scheduleActivity(
            uniqueName: request.uniqueName,
            isPeriodic: true,
            interval: frequencySeconds,
            tolerance: nil,
            inputData: request.inputData as? [String: Any],
            taskName: request.taskName
        )

        let taskInfo = TaskDebugInfo(
            taskName: request.taskName,
            uniqueName: request.uniqueName,
            inputData: request.inputData as? [String: Any],
            startTime: Date().timeIntervalSince1970
        )
        WorkmanagerDebug.getCurrent().onTaskStatusUpdate(taskInfo: taskInfo, status: .scheduled, result: nil)
        completion(.success(()))
        #endif
    }

    func registerProcessingTask(request: ProcessingTaskRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        guard validateCallbackHandle() else {
            completion(.failure(createInitializationError()))
            return
        }

        #if os(iOS)
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
        #elseif os(macOS)
        // NSBackgroundActivityScheduler has no network/charging constraints;
        // processing tasks map to a one-off activity scheduled best-effort.
        let delaySeconds = Double(request.initialDelaySeconds ?? 0)

        WorkmanagerPlugin.scheduleActivity(
            uniqueName: request.uniqueName,
            isPeriodic: false,
            interval: delaySeconds,
            tolerance: 0,
            inputData: request.inputData as? [String: Any],
            taskName: request.taskName
        )

        let taskInfo = TaskDebugInfo(
            taskName: request.taskName,
            uniqueName: request.uniqueName,
            inputData: request.inputData as? [String: Any],
            startTime: Date().timeIntervalSince1970
        )
        WorkmanagerDebug.getCurrent().onTaskStatusUpdate(taskInfo: taskInfo, status: .scheduled, result: nil)
        completion(.success(()))
        #endif
    }

    func cancelByUniqueName(uniqueName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        #if os(iOS)
        executeIfSupportedVoid(completion: completion, feature: "cancelByUniqueName") {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: uniqueName)
        }
        #elseif os(macOS)
        WorkmanagerPlugin.activityRegistryLock.lock()
        WorkmanagerPlugin.scheduledActivities.removeValue(forKey: uniqueName)?.invalidate()
        WorkmanagerPlugin.activityRegistryLock.unlock()
        completion(.success(()))
        #endif
    }

    func cancelByTag(tag: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Tags are not supported on iOS/macOS - this is an Android-specific feature
        completion(.success(()))
    }

    func cancelAll(completion: @escaping (Result<Void, Error>) -> Void) {
        #if os(iOS)
        executeIfSupportedVoid(completion: completion, feature: "cancelAll") {
            BGTaskScheduler.shared.cancelAllTaskRequests()
        }
        #elseif os(macOS)
        WorkmanagerPlugin.activityRegistryLock.lock()
        let activities = Array(WorkmanagerPlugin.scheduledActivities.values)
        WorkmanagerPlugin.scheduledActivities.removeAll()
        WorkmanagerPlugin.activityRegistryLock.unlock()
        activities.forEach { $0.invalidate() }
        completion(.success(()))
        #endif
    }

    func isScheduledByUniqueName(uniqueName: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        #if os(iOS)
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.getPendingTaskRequests { taskRequests in
                let isScheduled = taskRequests.contains { $0.identifier == uniqueName }
                completion(.success(isScheduled))
            }
        } else {
            completion(.success(false))
        }
        #elseif os(macOS)
        WorkmanagerPlugin.activityRegistryLock.lock()
        let isScheduled = WorkmanagerPlugin.scheduledActivities[uniqueName] != nil
        WorkmanagerPlugin.activityRegistryLock.unlock()
        completion(.success(isScheduled))
        #endif
    }

    func printScheduledTasks(completion: @escaping (Result<String, Error>) -> Void) {
        #if os(iOS)
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
        #elseif os(macOS)
        WorkmanagerPlugin.activityRegistryLock.lock()
        let activities = Array(WorkmanagerPlugin.scheduledActivities.values)
        WorkmanagerPlugin.activityRegistryLock.unlock()

        if activities.isEmpty {
            let message = "[NSBackgroundActivityScheduler] There are no scheduled activities"
            log(message)
            completion(.success(message))
            return
        }

        var message = "[NSBackgroundActivityScheduler] Scheduled Activities:"
        for activity in activities {
            message += "\n[NSBackgroundActivityScheduler] Activity Identifier: \(activity.identifier) interval: \(activity.interval)s repeats: \(activity.repeats)"
        }
        log("\(message)")
        completion(.success(message))
        #endif
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

    #if os(iOS)
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
    #endif
}

// MARK: - FlutterPlugin conformance

extension WorkmanagerPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = WorkmanagerPlugin()
        #if os(iOS)
        WorkmanagerHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
        #elseif os(macOS)
        WorkmanagerHostApiSetup.setUp(binaryMessenger: registrar.messenger, api: instance)
        #endif
        #if os(iOS)
        registrar.addApplicationDelegate(instance)
        #endif
    }
}

// MARK: - AppDelegate conformance (iOS only)

#if os(iOS)
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

        return worker.performBackgroundRequest { result in
            completionHandler(result == .newData ? .newData : .failed)
        }
    }
}
#endif
