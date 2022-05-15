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
            struct RegisterOneOffTask {
                static let name = "\(RegisterOneOffTask.self)".lowercasingFirst
                enum Arguments: String {
                    case uniqueName
                    case initialDelaySeconds
                    case networkType
                    case requiresCharging
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
    public static func registerTask(withIdentifier identifier: String) {
        if #available(iOS 13.0, *) {
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
            let method = ForegroundMethodChannel.Methods.Initialize.self
            guard let isInDebug = arguments[method.Arguments.isInDebugMode.rawValue] as? Bool,
                  let handle = arguments[method.Arguments.callbackHandle.rawValue] as? Int64 else {
                result(WMPError.invalidParameters.asFlutterError)
                return
            }

            UserDefaultsHelper.storeCallbackHandle(handle)
            UserDefaultsHelper.storeIsDebug(isInDebug)
            result(true)

        case (ForegroundMethodChannel.Methods.RegisterOneOffTask.name, let .some(arguments)):
            if !validateCallbackHandle() {
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
                return
            }

            if #available(iOS 13.0, *) {
                let method = ForegroundMethodChannel.Methods.RegisterOneOffTask.self
                guard let initialDelaySeconds =
                        arguments[method.Arguments.initialDelaySeconds.rawValue] as? Int64 else {
                    result(WMPError.invalidParameters.asFlutterError)
                    return
                }
                guard let identifier =
                        arguments[method.Arguments.uniqueName.rawValue] as? String else {
                    result(WMPError.invalidParameters.asFlutterError)
                    return
                }
                let request = BGProcessingTaskRequest(
                    identifier: identifier
                )
                let requiresCharging = arguments[method.Arguments.requiresCharging.rawValue] as? Bool ?? false

                var requiresNetworkConnectivity = false
                if let networkTypeInput = arguments[method.Arguments.networkType.rawValue] as? String,
                   let networkType = NetworkType(fromDart: networkTypeInput),
                   networkType == .connected || networkType == .metered {
                    requiresNetworkConnectivity = true
                }

                request.earliestBeginDate = Date(timeIntervalSinceNow: Double(initialDelaySeconds))
                request.requiresExternalPower = requiresCharging
                request.requiresNetworkConnectivity = requiresNetworkConnectivity

                do {
                    try BGTaskScheduler.shared.submit(request)
                    result(true)
                } catch {
                    result(WMPError.bgTaskSchedulingFailed(error).asFlutterError)
                }

                return
            } else {
                result(WMPError.unhandledMethod(call.method).asFlutterError)
            }

        case (ForegroundMethodChannel.Methods.CancelAllTasks.name, .none):
            if #available(iOS 13.0, *) {
                BGTaskScheduler.shared.cancelAllTaskRequests()
            }
            result(true)

        case (ForegroundMethodChannel.Methods.CancelTaskByUniqueName.name, let .some(arguments)):
            if #available(iOS 13.0, *) {
                let method = ForegroundMethodChannel.Methods.CancelTaskByUniqueName.self
                guard let identifier = arguments[method.Arguments.uniqueName.rawValue] as? String else {
                    result(WMPError.invalidParameters.asFlutterError)
                    return
                }
                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
            }
            result(true)

        default:
            result(WMPError.unhandledMethod(call.method).asFlutterError)
            return
        }
    }

    private func validateCallbackHandle() -> Bool {
        return UserDefaultsHelper.getStoredCallbackHandle() != nil
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
