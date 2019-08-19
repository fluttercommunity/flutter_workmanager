import Flutter
import UIKit
import os

public class SwiftWorkmanagerPlugin: FlutterPluginAppLifeCycleDelegate {
    
    static let identifier = "be.tramckrijte.workmanager"
    
    
    private struct ForegroundMethodChannel {
        static let channelName = "\(SwiftWorkmanagerPlugin.identifier)/foreground_channel_work_manager"
        
        struct methods {
            struct initialize {
                static let name = "\(initialize.self)"
                enum arguments: String {
                    case isInDebugMode
                    case callbackHandle
                }
            }
        }
        
    }
    
    private struct BackgroundMethodChannel {
        static let channelName = "\(SwiftWorkmanagerPlugin.identifier)/background_channel_work_manager"
        static let backgroundChannelInitializedMethod = "backgroundChannelInitialized"
        static let iOSPerformFetchMethodName = "onResultSend"
        static let iOSPerformFetchTaskName = "iOSPerformFetch"
    }
    
    private let flutterThreadLabelPrefix = "\(SwiftWorkmanagerPlugin.identifier).BackgroundFetch"
    
}

//MARK: - FlutterPlugin conformance

extension SwiftWorkmanagerPlugin: FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        
        let foregroundMethodChannel = FlutterMethodChannel(name: ForegroundMethodChannel.channelName, binaryMessenger: registrar.messenger())
        let instance = SwiftWorkmanagerPlugin()
        registrar.addMethodCallDelegate(instance, channel: foregroundMethodChannel)
        registrar.addApplicationDelegate(instance)
        
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        switch (call.method, call.arguments as? [AnyHashable: Any]) {
        case (ForegroundMethodChannel.methods.initialize.name, let .some(arguments)):
            let isInDebug = arguments[ForegroundMethodChannel.methods.initialize.arguments.isInDebugMode.rawValue] as! Bool
            let handle = arguments[ForegroundMethodChannel.methods.initialize.arguments.callbackHandle.rawValue] as! Int64
            UserDefaultsHelper.storeCallbackHandle(handle)
            UserDefaultsHelper.storeIsDebug(isInDebug)
            result(true)
        default:
            result(WMPError.unhandledMethod(call.method).asFlutterError)
            return
        }
        
    }
    
}

//MARK: - AppDelegate conformance

extension SwiftWorkmanagerPlugin {
    
    override public func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) -> Bool {
        
        guard let callbackHandle = UserDefaultsHelper.getStoredCallbackHandle(),
            let flutterCallbackInformation = FlutterCallbackCache.lookupCallbackInformation(callbackHandle)
            else {
                logError("[\(String(describing: self))] \(WMPError.workmanagerNotInitialized.message)")
                completionHandler(.failed)
                return false
        }
        
        let fetchSessionStart = Date()
        let fetchSessionIdentifier = UUID()
        DebugNotificationHelper.showStartFetchNotification(identifier: fetchSessionIdentifier,
                                                           startDate: fetchSessionStart,
                                                           callBackHandle: callbackHandle,
                                                           callbackInfo: flutterCallbackInformation)
        var flutterEngine: FlutterEngine? = FlutterEngine(name: flutterThreadLabelPrefix, project: nil, allowHeadlessExecution: true)
        flutterEngine!.run(withEntrypoint: flutterCallbackInformation.callbackName, libraryURI: flutterCallbackInformation.callbackLibraryPath)
        var backgroundMethodChannel: FlutterMethodChannel? = FlutterMethodChannel(name: BackgroundMethodChannel.channelName, binaryMessenger: flutterEngine!)
        
        func cleanupFlutterResources() {
            flutterEngine?.destroyContext()
            backgroundMethodChannel = nil
            flutterEngine = nil
        }
        
        backgroundMethodChannel?.setMethodCallHandler { (call, result) in
            switch call.method {
            case BackgroundMethodChannel.backgroundChannelInitializedMethod:
                result(true)    // Agree to Flutter's method invocation
                
                let taskName = BackgroundMethodChannel.iOSPerformFetchTaskName
                backgroundMethodChannel?.invokeMethod(BackgroundMethodChannel.iOSPerformFetchMethodName, arguments: taskName, result: { flutterResult in
                    cleanupFlutterResources()
                    let fetchSessionCompleted = Date()
                    let result: UIBackgroundFetchResult = flutterResult as! Bool ? .newData : .failed
                    let fetchDuration = fetchSessionCompleted.timeIntervalSince(fetchSessionStart)
                    let message = "[\(String(describing: self))] \(#function) -> UIBackgroundFetchResult.\(result) (finished in \(fetchDuration.formatToSeconds()))"
                    logInfo(message)
                    DebugNotificationHelper.showCompletedFetchNotification(identifier: fetchSessionIdentifier,
                                                                           completedDate: fetchSessionCompleted,
                                                                           result: result,
                                                                           elapsedTime: fetchDuration)
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
