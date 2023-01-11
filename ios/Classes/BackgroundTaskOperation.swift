//
//  BackgroundTaskOperation.swift
//  workmanager
//
//  Created by Sebastian Roth on 10/06/2021.
//

import Foundation

/// Backgroundoperation with maximum 29 sec operation time - specification by iOS
/// Task will killed after 29sec because  otherwise iOS will kill the app.
class BackgroundTaskOperation: Operation {
    private let identifier: String
    private let inputData: String
    private let flutterPluginRegistrantCallback: FlutterPluginRegistrantCallback?
    private let backgroundMode: BackgroundMode
    private let isInDebug: Bool

    private var backgroundWorkerResult: UIBackgroundFetchResult = .noData

    init(_ identifier: String,
         inputData: String,
         flutterPluginRegistrantCallback: FlutterPluginRegistrantCallback?,
         backgroundMode: BackgroundMode,
         isInDebug: Bool) {
        self.identifier = identifier
        self.inputData = inputData
        self.flutterPluginRegistrantCallback = flutterPluginRegistrantCallback
        self.backgroundMode = backgroundMode
        self.isInDebug = isInDebug
    }

    
    override func main() {
        let taskSessionIdentifier = UUID()
        let taskSessionStart = Date()

        if isInDebug {
            guard let callbackHandle = UserDefaultsHelper.getStoredCallbackHandle(),
                  let flutterCallbackInformation = FlutterCallbackCache.lookupCallbackInformation(callbackHandle)
            else {
                logError("[\(String(describing: self))] \(WMPError.workmanagerNotInitialized.message)")
                return
            }
            let debugHelper = DebugNotificationHelper(taskSessionIdentifier)
            debugHelper.showStartFetchNotification(
                startDate: taskSessionStart,
                callBackHandle: callbackHandle,
                callbackInfo: flutterCallbackInformation
            )
        }

        let semaphore = DispatchSemaphore(value: 0)
        let worker = BackgroundWorker(mode: self.backgroundMode,
                                                  inputData: self.inputData,
                                                  flutterPluginRegistrantCallback: self.flutterPluginRegistrantCallback)
        DispatchQueue.main.async {

            worker.performBackgroundRequest { wk in
                self.backgroundWorkerResult = wk as UIBackgroundFetchResult;
                semaphore.signal()
            }
        }
        switch backgroundMode {
        case .backgroundProcessingTask:
            semaphore.wait()

            if isInDebug {
                let debugHelper = DebugNotificationHelper(taskSessionIdentifier)
                let taskSessionCompleter = Date()
                let taskDuration = taskSessionCompleter.timeIntervalSince(taskSessionStart)
                logInfo("[\(String(describing: self))] \(#function) -> BackgroundTaskOperation.main (\(self.backgroundMode) no timeout) (finished in  \(taskDuration.formatToSeconds()))")
                debugHelper.showCompletedFetchNotification(
                    identifier: identifier,
                    completedDate: taskSessionCompleter,
                    result: self.backgroundWorkerResult,
                    elapsedTime: taskDuration
                )
            }
            break

        default:
            /// maximum execution time 29 seconds + 1 second flutterstuff (callback etc)
            let result = semaphore.wait(timeout: DispatchTime.now() + 29)

            if isInDebug {
                let debugHelper = DebugNotificationHelper(taskSessionIdentifier)
                let taskSessionCompleter = Date()
                let taskDuration = taskSessionCompleter.timeIntervalSince(taskSessionStart)
                logInfo("[\(String(describing: self))] \(#function) -> BackgroundTaskOperation.main (\(self.backgroundMode) timeout 29sec)(finished in  \(taskDuration.formatToSeconds()))")
                debugHelper.showCompletedFetchNotification(
                    identifier: identifier,
                    completedDate: taskSessionCompleter,
                    result: result == DispatchTimeoutResult.success ? self.backgroundWorkerResult : UIBackgroundFetchResult.failed,
                    elapsedTime: taskDuration
                )
            }
        }
    }
}
