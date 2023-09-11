//
//  BackgroundWorker.swift
//  workmanager
//
//  Created by Sebastian Roth on 10/06/2021.
//

import Foundation

enum BackgroundMode {
    case backgroundAppRefresh
    case backgroundProcessingTask
    case backgroundOnOffTask(identifier: String)

    var flutterThreadlabelPrefix: String {
        switch self {
        case .backgroundAppRefresh:
            return "\(SwiftWorkmanagerPlugin.identifier).BackgroundAppRefreshTask"
        case .backgroundProcessingTask:
            return "\(SwiftWorkmanagerPlugin.identifier).BackgroundProcessingTask"
        case .backgroundOnOffTask:
            return "\(SwiftWorkmanagerPlugin.identifier).OnOffTask"
        }
    }

    var onResultSendArguments: [String: String] {
        switch self {
        case .backgroundAppRefresh:
            return ["\(SwiftWorkmanagerPlugin.identifier).DART_TASK": "iOSBackgroundAppRefresh"]
        case .backgroundProcessingTask:
            return ["\(SwiftWorkmanagerPlugin.identifier).DART_TASK": "iOSBackgroundProcessingTask"]
        case let .backgroundOnOffTask(identifier):
            return ["\(SwiftWorkmanagerPlugin.identifier).DART_TASK": identifier]
        }
    }
}

class BackgroundWorker {
    let backgroundMode: BackgroundMode
    let inputData: String
    let flutterPluginRegistrantCallback: FlutterPluginRegistrantCallback?

    init(mode: BackgroundMode, inputData: String, flutterPluginRegistrantCallback: FlutterPluginRegistrantCallback?) {
        backgroundMode = mode
        self.inputData = inputData
        self.flutterPluginRegistrantCallback = flutterPluginRegistrantCallback
    }

    private struct BackgroundChannel {
        static let name = "\(SwiftWorkmanagerPlugin.identifier)/background_channel_work_manager"
        static let initialized = "backgroundChannelInitialized"
        static let onResultSendCommand = "onResultSend"
    }

    /// The result is discardable due to how [BackgroundTaskOperation] works.
    @discardableResult
    func performBackgroundRequest(_ completionHandler: @escaping (UIBackgroundFetchResult) -> Void) -> Bool {
        guard let callbackHandle = UserDefaultsHelper.getStoredCallbackHandle(),
              let flutterCallbackInformation = FlutterCallbackCache.lookupCallbackInformation(callbackHandle)
        else {
            logError("[\(String(describing: self))] \(WMPError.workmanagerNotInitialized.message)")
            completionHandler(.failed)
            return false
        }

        let taskSessionStart = Date()

        var flutterEngine: FlutterEngine? = FlutterEngine(
            name: backgroundMode.flutterThreadlabelPrefix,
            project: nil,
            allowHeadlessExecution: true
        )

        flutterEngine!.run(
            withEntrypoint: flutterCallbackInformation.callbackName,
            libraryURI: flutterCallbackInformation.callbackLibraryPath
        )
        flutterPluginRegistrantCallback?(flutterEngine!)

        var backgroundMethodChannel: FlutterMethodChannel? = FlutterMethodChannel(
            name: BackgroundChannel.name,
            binaryMessenger: flutterEngine!.binaryMessenger
        )

        func cleanupFlutterResources() {
            flutterEngine?.destroyContext()
            backgroundMethodChannel = nil
            flutterEngine = nil
        }

        backgroundMethodChannel?.setMethodCallHandler { call, result in
            switch call.method {
            case BackgroundChannel.initialized:
                result(true) // Agree to Flutter's method invocation
                    var arguments = self.backgroundMode.onResultSendArguments
                    if self.inputData != ""{
                        arguments = arguments.merging(["be.tramckrijte.workmanager.INPUT_DATA": self.inputData]) { current, _ in current }
                        logDebug("[\(String(describing: self))] \(#function) -> BackgroundWorker.backgroundMethodChannel \(arguments.debugDescription) will called. INPUT_DATA: \(self.inputData)")

                    }

                backgroundMethodChannel?.invokeMethod(
                    BackgroundChannel.onResultSendCommand,
                    arguments:arguments,
                    result: { flutterResult in
                        cleanupFlutterResources()
                        let taskSessionCompleter = Date()
                        let result: UIBackgroundFetchResult = (flutterResult as? Bool ?? false) ? .newData : .failed
                        let taskDuration = taskSessionCompleter.timeIntervalSince(taskSessionStart)
                        logInfo("[\(String(describing: self))] \(#function) -> performBackgroundRequest.\(result) (finished in \(taskDuration.formatToSeconds()))")

                        completionHandler(result)
                    })
            default:
                result(WMPError.unhandledMethod(call.method).asFlutterError)
                cleanupFlutterResources()
                completionHandler(UIBackgroundFetchResult.failed)
            }
        }

        return true
    }
}
