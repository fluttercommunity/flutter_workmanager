import Foundation

#if os(iOS)
import BackgroundTasks
#endif

/// Registration, scheduling and execution of BGContinuedProcessingTask (iOS 26+).
///
/// Continued processing tasks begin immediately or shortly after submission
/// and continue running while the app is backgrounded. This API surface lives
/// in its own file (mirroring the other task-type files) to keep
/// `WorkmanagerPlugin.swift` within SwiftLint's file length limit.
extension WorkmanagerPlugin {
    // MARK: - WorkmanagerHostApi implementation (iOS)

    #if os(iOS)
    func registerContinuedProcessingTask(
        request: ContinuedProcessingTaskRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard validateCallbackHandle() else {
            completion(.failure(createInitializationError()))
            return
        }

        guard #available(iOS 26.0, *) else {
            completion(.failure(PigeonError(
                code: "99",
                message: "ContinuedProcessingTask could not be registered",
                details: "BGContinuedProcessingTaskRequest is only supported on iOS 26+"
            )))
            return
        }

        // The task is meant to begin immediately or shortly after submission;
        // the scheduler ignores `earliestBeginDate`, so there is no
        // initialDelay. Persist inputData keyed by the task identifier so it
        // is available when the task is delivered (mirroring the periodic and
        // health research task paths).
        UserDefaultsHelper.storePeriodicTaskInputData(
            request.inputData as? [String: Any],
            forTaskIdentifier: request.uniqueName
        )

        WorkmanagerPlugin.scheduleContinuedProcessingTask(
            withIdentifier: request.uniqueName,
            title: request.title ?? request.taskName,
            subtitle: request.subtitle ?? ""
        )

        let taskInfo = TaskDebugInfo(
            taskName: request.taskName,
            uniqueName: request.uniqueName,
            inputData: request.inputData as? [String: Any],
            startTime: Date().timeIntervalSince1970,
            isPeriodic: false
        )
        WorkmanagerDebug.onTaskStatusUpdate(taskInfo: taskInfo, status: .scheduled, result: nil)
        completion(.success(()))
    }
    #elseif os(macOS)
    func registerContinuedProcessingTask(
        request: ContinuedProcessingTaskRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // BGContinuedProcessingTaskRequest is iOS 26+-only and presents a Live
        // Activity while running; it is not available on macOS.
        completion(.failure(PigeonError(
            code: "99",
            message: "ContinuedProcessingTask could not be registered",
            details: "BGContinuedProcessingTaskRequest is only supported on iOS 26+"
        )))
    }
    #endif

    // MARK: - Continued processing task scheduling (iOS only)

    #if os(iOS)
    /// Registers a continued processing task with iOS BGTaskScheduler.
    ///
    /// Continued processing tasks (iOS 26+) begin immediately or shortly after
    /// submission and are allowed to continue running while the app is
    /// backgrounded. The identifier must use wildcard notation ending in `.*`
    /// (e.g. `<bundleID>.<context>.*`) and be listed in
    /// `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
    ///
    /// - Parameter identifier: Unique task identifier that matches the one used in Dart
    @objc
    public static func registerBGContinuedProcessingTask(withIdentifier identifier: String) {
        guard #available(iOS 26.0, *) else {
            return
        }
        UserDefaultsHelper.storeScheduledTask(
            ScheduledTaskInfo(kind: .continuedProcessing, earliestBeginInSeconds: nil),
            forTaskIdentifier: identifier
        )
        registerLaunchHandlerOnce(forTaskWithIdentifier: identifier, earliestBeginInSeconds: nil)
    }

    @available(iOS 26.0, *)
    private static func scheduleContinuedProcessingTask(
        withIdentifier uniqueTaskIdentifier: String,
        title: String,
        subtitle: String
    ) {
        let request = BGContinuedProcessingTaskRequest(
            identifier: uniqueTaskIdentifier,
            title: title,
            subtitle: subtitle
        )

        do {
            try BGTaskScheduler.shared.submit(request)
            logInfo("BGContinuedProcessingTask submitted \(uniqueTaskIdentifier)")
            UserDefaultsHelper.storeScheduledTask(
                ScheduledTaskInfo(kind: .continuedProcessing, earliestBeginInSeconds: nil),
                forTaskIdentifier: uniqueTaskIdentifier
            )
            registerLaunchHandlerOnce(forTaskWithIdentifier: uniqueTaskIdentifier, earliestBeginInSeconds: nil)
        } catch {
            logInfo(
                "Could not schedule BGContinuedProcessingTask identifier:\(uniqueTaskIdentifier) " +
                    "error:\(error.localizedDescription)"
            )
            logInfo(
                "Possible issues: iOS 26+ required, the identifier must end with '.*' " +
                    "(e.g. <bundleID>.<context>.*), or the task name is not registered " +
                    "in BGTaskSchedulerPermittedIdentifiers"
            )
        }
    }

    /// Handles execution of a continued processing background task.
    ///
    /// BGContinuedProcessingTask starts near submission time and can continue
    /// while the app is backgrounded; the system still enforces an expiration
    /// based on changing system conditions (the handler cancels the operation).
    @available(iOS 26.0, *)
    static func handleBGContinuedProcessingTask(identifier: String, task: BGContinuedProcessingTask) {
        let operationQueue = OperationQueue()
        // Deliver the inputData stored at registration time (mirroring the
        // periodic task path, keyed by task identifier).
        let storedInputData = UserDefaultsHelper.getStoredPeriodicTaskInputData(forTaskIdentifier: task.identifier)
        let operation = createBackgroundOperation(
            identifier: task.identifier,
            inputData: storedInputData,
            backgroundMode: .backgroundContinuedProcessingTask(identifier: identifier)
        )

        task.expirationHandler = { operation.cancel() }
        operation.completionBlock = { task.setTaskCompleted(success: !operation.isCancelled) }

        operationQueue.addOperation(operation)
    }
    #endif
}
