//
//  BackgroundWorker.swift
//  workmanager
//
//  Created by Sebastian Roth on 10/06/2021.
//

import Foundation

enum BackgroundMode {
    case backgroundFetch
    case backgroundTask(identifier: String)

    var flutterThreadlabelPrefix: String {
        switch self {
        case .backgroundFetch:
            return "\(SwiftWorkmanagerPlugin.identifier).BackgroundFetch"
        case .backgroundTask:
            return "\(SwiftWorkmanagerPlugin.identifier).BGTaskScheduler"
        }
    }

    var onResultSendArguments: [String: String] {
        switch self {
        case .backgroundFetch:
            return ["\(SwiftWorkmanagerPlugin.identifier).DART_TASK": "iOSPerformFetch"]
        case .backgroundTask(let identifier):
            return ["\(SwiftWorkmanagerPlugin.identifier).DART_TASK": identifier]
        }
    }
}

class BackgroundWorker {

    let backgroundMode: BackgroundMode
    let flutterPluginRegistrantCallback: FlutterPluginRegistrantCallback?

    init(mode: BackgroundMode, flutterPluginRegistrantCallback: FlutterPluginRegistrantCallback?) {
        self.backgroundMode = mode
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
        let taskSessionIdentifier = UUID()

        let debugHelper = DebugNotificationHelper(taskSessionIdentifier)
        debugHelper.showStartFetchNotification(
            startDate: taskSessionStart,
            callBackHandle: callbackHandle,
            callbackInfo: flutterCallbackInformation
        )

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

        backgroundMethodChannel?.setMethodCallHandler { (call, result) in
            switch call.method {
            case BackgroundChannel.initialized:
                result(true)    // Agree to Flutter's method invocation

                backgroundMethodChannel?.invokeMethod(
                    BackgroundChannel.onResultSendCommand,
                    arguments: self.backgroundMode.onResultSendArguments,
                    result: { flutterResult in
                        cleanupFlutterResources()
                        let taskSessionCompleter = Date()
                        let result: UIBackgroundFetchResult = (flutterResult as? Bool ?? false) ? .newData : .failed
                        let taskDuration = taskSessionCompleter.timeIntervalSince(taskSessionStart)
                        logInfo("[\(String(describing: self))] \(#function) -> performBackgroundRequest.\(result) (finished in \(taskDuration.formatToSeconds()))")

                        debugHelper.showCompletedFetchNotification(
                            completedDate: taskSessionCompleter,
                            result: result,
                            elapsedTime: taskDuration
                        )
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
