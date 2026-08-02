//
//  BackgroundWorker.swift
//  workmanager
//
//  Created by Sebastian Roth on 10/06/2021.
//

import Foundation

#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#else
#error("Unsupported platform.")
#endif

/// Cross-platform alias for the closure that registers plugins on a Flutter
/// engine. iOS exposes `FlutterPluginRegistrantCallback`; macOS does not, so we
/// use an equivalent closure over `FlutterPluginRegistry`.
#if os(iOS)
typealias WMPFlutterPluginRegistrantCallback = FlutterPluginRegistrantCallback
#elseif os(macOS)
typealias WMPFlutterPluginRegistrantCallback = (FlutterPluginRegistry) -> Void
#endif

enum BackgroundMode {
    case backgroundFetch
    case backgroundProcessingTask(identifier: String)
    case backgroundPeriodicTask(identifier: String)
    case backgroundOneOffTask(identifier: String)
    case backgroundHealthResearchTask(identifier: String)

    var flutterThreadlabelPrefix: String {
        switch self {
        case .backgroundFetch:
            return "\(WorkmanagerPlugin.identifier).BackgroundFetch"
        case .backgroundProcessingTask:
            return "\(WorkmanagerPlugin.identifier).BackgroundProcessingTask"
        case .backgroundPeriodicTask:
            return "\(WorkmanagerPlugin.identifier).BackgroundPeriodicTask"
        case .backgroundOneOffTask:
            return "\(WorkmanagerPlugin.identifier).OneOffTask"
        case .backgroundHealthResearchTask:
            return "\(WorkmanagerPlugin.identifier).HealthResearchTask"
        }
    }

    var onResultSendArguments: [String: String] {
        switch self {
        case .backgroundFetch:
            return ["\(WorkmanagerPlugin.identifier).DART_TASK": "iOSPerformFetch"]
        case let .backgroundProcessingTask(identifier):
            return ["\(WorkmanagerPlugin.identifier).DART_TASK": identifier]
        case let .backgroundPeriodicTask(identifier):
            return ["\(WorkmanagerPlugin.identifier).DART_TASK": identifier]
        case let .backgroundOneOffTask(identifier):
            return ["\(WorkmanagerPlugin.identifier).DART_TASK": identifier]
        case let .backgroundHealthResearchTask(identifier):
            return ["\(WorkmanagerPlugin.identifier).DART_TASK": identifier]
        }
    }
}

/// Platform-neutral result of a background request execution.
///
/// iOS maps these to `UIBackgroundFetchResult` at the call site; macOS uses
/// them directly with `NSBackgroundActivityScheduler`.
enum BackgroundRequestResult {
    case newData
    case failed
}

extension BackgroundRequestResult: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .newData:
            return "newData"
        case .failed:
            return "failed"
        }
    }
}

class BackgroundWorker {

    let backgroundMode: BackgroundMode
    let flutterPluginRegistrantCallback: WMPFlutterPluginRegistrantCallback?
    let inputData: [String: Any]?

    init(
        mode: BackgroundMode, inputData: [String: Any]?,
        flutterPluginRegistrantCallback: WMPFlutterPluginRegistrantCallback?
    ) {
        backgroundMode = mode
        self.inputData = inputData
        self.flutterPluginRegistrantCallback = flutterPluginRegistrantCallback
    }

    private struct BackgroundChannel {
        static let name = "\(WorkmanagerPlugin.identifier)/background_channel_work_manager"
        static let initialized = "backgroundChannelInitialized"
        static let onResultSendCommand = "onResultSend"
    }

    /// The result is discardable due to how [BackgroundTaskOperation] works.
    @discardableResult
    func performBackgroundRequest(_ completionHandler: @escaping (BackgroundRequestResult) -> Void)
        -> Bool {
        guard let resolved = resolveBackgroundEntrypoint() else {
            logError("[\(String(describing: self))] \(WMPError.workmanagerNotInitialized.message)")
            completionHandler(.failed)
            return false
        }

        let taskSessionStart = Date()

        let taskInfo = TaskDebugInfo(
            taskName: "background_fetch",
            startTime: taskSessionStart.timeIntervalSince1970,
            callbackHandle: resolved.handle,
            callbackInfo: resolved.entrypoint.name
        )

        WorkmanagerDebug.onTaskStatusUpdate(taskInfo: taskInfo, status: .started)

        var flutterEngine: FlutterEngine? = FlutterEngine(
            name: backgroundMode.flutterThreadlabelPrefix,
            project: nil,
            allowHeadlessExecution: true
        )

#if os(iOS)
        flutterEngine!.run(
            withEntrypoint: resolved.entrypoint.name,
            libraryURI: resolved.entrypoint.libraryURI!
        )
#elseif os(macOS)
        flutterEngine!.run(withEntrypoint: resolved.entrypoint.name)
#endif
        flutterPluginRegistrantCallback?(flutterEngine!)

        var flutterApi: WorkmanagerFlutterApi? = WorkmanagerFlutterApi(binaryMessenger: flutterEngine!.binaryMessenger)

        func cleanupFlutterResources() {
#if os(iOS)
            flutterEngine?.destroyContext()
#elseif os(macOS)
            flutterEngine?.shutDownEngine()
#endif
            flutterApi = nil
            flutterEngine = nil
        }

        // Initialize the background channel and execute the task
        flutterApi?.backgroundChannelInitialized { result in
            switch result {
            case .success:
                // Get the task name from backgroundMode
                let taskName = self.backgroundMode.onResultSendArguments["\(WorkmanagerPlugin.identifier).DART_TASK"] ?? ""

                // Convert inputData to the format expected by Pigeon
                var pigeonInputData: [String?: Any?]?
                if let inputData = self.inputData {
                    pigeonInputData = Dictionary(uniqueKeysWithValues: inputData.map { ($0.key as String?, $0.value as Any?) })
                }

                // Execute the task
                flutterApi?.executeTask(taskName: taskName, inputData: pigeonInputData) { taskResult in
                    cleanupFlutterResources()
                    let taskSessionCompleter = Date()

                    let fetchResult: BackgroundRequestResult
                    let status: TaskStatus
                    let errorMessage: String?

                    switch taskResult {
                    case .success(let wasSuccessful):
                        if wasSuccessful {
                            fetchResult = .newData
                            status = .completed
                            errorMessage = nil
                        } else {
                            fetchResult = .failed
                            status = .retrying
                            errorMessage = nil
                        }
                    case .failure(let error):
                        fetchResult = .failed
                        status = .failed
                        errorMessage = error.localizedDescription
                    }

                    let taskDuration = taskSessionCompleter.timeIntervalSince(taskSessionStart)
                    logInfo(
                        "[\(String(describing: self))] \(#function) -> performBackgroundRequest.\(fetchResult) (finished in \(taskDuration.formatToSeconds()))"
                    )

                    let taskResult = TaskResult(
                        success: status == .completed,
                        duration: Int64(taskDuration * 1000), // Convert to milliseconds
                        error: errorMessage
                    )
                    WorkmanagerDebug.onTaskStatusUpdate(taskInfo: taskInfo, status: status, result: taskResult)
                    completionHandler(fetchResult)
                }
            case .failure(let error):
                logError("Background channel initialization failed: \(error)")
                cleanupFlutterResources()
                completionHandler(.failed)
            }
        }

        return true
    }

    /// Entrypoint information used to start the background engine.
    private struct BackgroundEntrypoint {
        let name: String
        let libraryURI: String?
    }

    /// Resolves the stored callback handle and the engine entrypoint.
    ///
    /// iOS looks the callback up by handle via FlutterCallbackCache. macOS has
    /// no equivalent API: the dispatcher must be a top-level function named
    /// `callbackDispatcher` in the app's main library.
    private func resolveBackgroundEntrypoint() -> (handle: Int64, entrypoint: BackgroundEntrypoint)? {
#if os(iOS)
        guard let callbackHandle = UserDefaultsHelper.getStoredCallbackHandle(),
            let callbackInformation = FlutterCallbackCache.lookupCallbackInformation(
                callbackHandle)
        else {
            return nil
        }
        return (
            callbackHandle,
            BackgroundEntrypoint(
                name: callbackInformation.callbackName,
                libraryURI: callbackInformation.callbackLibraryPath
            )
        )
#elseif os(macOS)
        guard let callbackHandle = UserDefaultsHelper.getStoredCallbackHandle() else {
            return nil
        }
        return (
            callbackHandle,
            BackgroundEntrypoint(name: "callbackDispatcher", libraryURI: nil)
        )
#endif
    }
}
