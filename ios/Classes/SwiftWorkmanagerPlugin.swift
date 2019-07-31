import Flutter
import UIKit
import os

public class SwiftWorkmanagerPlugin: FlutterPluginAppLifeCycleDelegate {
    
    private struct ForegroundMethodChannel {
        static let channelName = "be.tramckrijte.workmanager/foreground_channel_work_manager"
        enum methods: String {
            case initialize
        }
    }
    
    private struct BackgroundMethodChannel {
        static let channelName = "be.tramckrijte.workmanager/background_channel_work_manager"
        enum methods: String {
            case backgroundChannelInitialized
            case iOSPerformFetch
        }
    }
    
    private let flutterThreadLabelPrefix = "BackgroundFetch"
    
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
            guard let callbackHandle: Int64 = call.arguments as? Int64 else {
                result(WMPError.unexpectedMethodArguments(call.arguments.debugDescription))
                return
            }
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
        
        // First, let's retreive our callBack handle
        guard let callbackHandle: Int64 = getStoredCallbackHandle() else {
            let errorMessage = "[\(#file)] Could not start the Flutter engine : no stored callback handle."
            if #available(iOS 10.0, *) {
                os_log("%@", errorMessage)
            } else {
                NSLog(errorMessage)
            }
            completionHandler(.failed)
            return false
        }
        
        // Then, run the Flutter engine with the retreivedf callback's name and libraryPath
        let flutterCallbackInformation: FlutterCallbackInformation = FlutterCallbackCache.lookupCallbackInformation(callbackHandle)
        let flutterEngine = FlutterEngine.init(name: flutterThreadLabelPrefix, project: nil, allowHeadlessExecution: true)!
        flutterEngine.run(withEntrypoint: flutterCallbackInformation.callbackName, libraryURI: flutterCallbackInformation.callbackLibraryPath)
        
        // Since we're now running a specific Flutter engine, no MethodChannel exists ; let's create one for WorkManager's BackgroundMethodChannel
        let backgroundMethodChannel = FlutterMethodChannel(name: BackgroundMethodChannel.channelName, binaryMessenger: flutterEngine)
        backgroundMethodChannel.setMethodCallHandler { (call, result) in
            switch call.method {
            case BackgroundMethodChannel.methods.backgroundChannelInitialized.rawValue:
                // BackgroundChannel is now available ; let's send the "iOSPerformFetch" method through it, and wait for the result
                backgroundMethodChannel.invokeMethod(BackgroundMethodChannel.methods.iOSPerformFetch.rawValue, arguments: nil, result: { flutterResult in
                    // We got a backgroundFetch result ; let's ensure we can convert it to a native UIBackgroundFetchResult
                    guard
                        let fetchResult: Int = flutterResult as? Int,
                        let backgroundFetchResult = UIBackgroundFetchResult.init(rawValue: UInt(fetchResult))
                        else {
                            result(WMPError.unexpectedMethodArguments(flutterResult.debugDescription))
                            completionHandler(.failed)
                            return
                    }
                    
                    result(true)
                    completionHandler(backgroundFetchResult)
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

public extension SwiftWorkmanagerPlugin {
    
    static func clearStorage() {
        UserDefaults.standard.removeObject(forKey: callbackHandleStorageKey)
    }
    
}

private extension SwiftWorkmanagerPlugin {
    
    static var callbackHandleStorageKey: String {
        return "callBackHandleStorageKey"
    }
    
    
    func store(_ callbackHandle: Int64) {
        UserDefaults.standard.set(callbackHandle, forKey: type(of: self).callbackHandleStorageKey)
    }
    
    func getStoredCallbackHandle() -> Int64? {
        return UserDefaults.standard.value(forKey: type(of: self).callbackHandleStorageKey) as? Int64
    }
    
}
