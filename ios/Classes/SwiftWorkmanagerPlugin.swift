import Flutter
import UIKit
import os

public class SwiftWorkmanagerPlugin: FlutterPluginAppLifeCycleDelegate {
    
    private struct Plugin {
        static let identifier = "be.tramckrijte.workmanager"
        static let userDefaults = UserDefaults(suiteName: "\(Plugin.identifier).userDefaults")!
    }
    
    private struct ForegroundMethodChannel {
        static let channelName = "\(Plugin.identifier)/foreground_channel_work_manager"
        enum methods: String {
            case initialize
        }
    }
    
    private struct BackgroundMethodChannel {
        static let channelName = "\(Plugin.identifier)/background_channel_work_manager"
        enum methods: String {
            case backgroundChannelInitialized
            case iOSPerformFetch
        }
    }
    
    private let flutterThreadLabelPrefix = "\(Plugin.identifier).BackgroundFetch"
    
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
        
        switch call.method {
        case ForegroundMethodChannel.methods.initialize.rawValue:
            let callbackHandle = call.arguments as! Int64
            store(callbackHandle)
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
        
        guard let callbackHandle: Int64 = getStoredCallbackHandle(),
              let flutterCallbackInformation = FlutterCallbackCache.lookupCallbackInformation(callbackHandle)
        else {
            logError("[\(String(describing: self))] \(WMPError.workmanagerNotInitialized.message)")
            completionHandler(.failed)
            return false
        }
        
        let flutterEngine = FlutterEngine(name: flutterThreadLabelPrefix, project: nil, allowHeadlessExecution: true)!
        flutterEngine.run(withEntrypoint: flutterCallbackInformation.callbackName, libraryURI: flutterCallbackInformation.callbackLibraryPath)
        
        // Since we're now running a specific Flutter engine, no MethodChannel exists ; let's create one for WorkManager's BackgroundMethodChannel
        let backgroundMethodChannel = FlutterMethodChannel(name: BackgroundMethodChannel.channelName, binaryMessenger: flutterEngine)
        backgroundMethodChannel.setMethodCallHandler { (call, result) in
            switch call.method {
            case BackgroundMethodChannel.methods.backgroundChannelInitialized.rawValue:
                result(true)    // Agree to Flutter's method invocation
                
                backgroundMethodChannel.invokeMethod(BackgroundMethodChannel.methods.iOSPerformFetch.rawValue, arguments: nil, result: { flutterResult in
                    let logPrefix = "[\(String(describing: self))] \(#function) -> UIBackgroundFetchResult"
                    switch flutterResult as! Bool {
                    case true:
                        logInfo("\(logPrefix).newData")
                        completionHandler(.newData)
                    case false:
                        logInfo("\(logPrefix).failed")
                        completionHandler(.failed)
                    }
                })
            default:
                result(WMPError.unhandledMethod(call.method).asFlutterError)
                completionHandler(UIBackgroundFetchResult.failed)
            }
        }
        
        return true
    }
    
}

//MARK: - Storage

private extension SwiftWorkmanagerPlugin {
    
    private var callbackHandleStorageKey: String {
        return "\(Plugin.identifier).callBackHandleStorageKey"
    }
    
    
    func store(_ callbackHandle: Int64) {
        Plugin.userDefaults.set(callbackHandle, forKey: callbackHandleStorageKey)
    }
    
    func getStoredCallbackHandle() -> Int64? {
        return Plugin.userDefaults.value(forKey: callbackHandleStorageKey) as? Int64
    }
    
}
