import Flutter
import UIKit
import os

public class SwiftWorkmanagerPlugin: FlutterPluginAppLifeCycleDelegate {
    
    private struct RegistrationMethodChannel {
        static let channelName = "be.tramckrijte.workmanager/registration"
        enum methods: String {
            case initialize
        }
    }
    
    private struct ExecutionMethodChannel {
        static let channelName = "be.tramckrijte.workmanager/execution"
        enum methods: String {
            case flutterReadyForTaskExecution
            case iOSPerformFetch
        }
    }
    
    private let flutterThreadLabelPrefix = "BackgroundFetch"
    
}

//MARK: - FlutterPlugin conformance

extension SwiftWorkmanagerPlugin: FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        
        let registrationMethodChannel = FlutterMethodChannel(name: RegistrationMethodChannel.channelName, binaryMessenger: registrar.messenger())
        let instance = SwiftWorkmanagerPlugin()
        registrar.addMethodCallDelegate(instance, channel: registrationMethodChannel)
        registrar.addApplicationDelegate(instance)
        
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        switch call.method {
        case RegistrationMethodChannel.methods.initialize.rawValue:
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
        
        // First, let's retrieve our callBack handle
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
        
        // Then, run the Flutter engine with the retrieved callback's name and libraryPath
        let flutterCallbackInformation: FlutterCallbackInformation = FlutterCallbackCache.lookupCallbackInformation(callbackHandle)
        let flutterEngine = FlutterEngine.init(name: flutterThreadLabelPrefix, project: nil, allowHeadlessExecution: true)!
        flutterEngine.run(withEntrypoint: flutterCallbackInformation.callbackName, libraryURI: flutterCallbackInformation.callbackLibraryPath)
        
        // Since we're now running a specific Flutter engine, no MethodChannel exists ; let's create one for WorkManager's BackgroundMethodChannel
        let executionMethodChannel = FlutterMethodChannel(name: ExecutionMethodChannel.channelName, binaryMessenger: flutterEngine)
        executionMethodChannel.setMethodCallHandler { (call, result) in
            switch call.method {
            case ExecutionMethodChannel.methods.flutterReadyForTaskExecution.rawValue:
                result(true)    // Agree to Flutter's method invocation
                // BackgroundChannel is now available ; let's send the "iOSPerformFetch" method through it, and wait for the result
                executionMethodChannel.invokeMethod(ExecutionMethodChannel.methods.iOSPerformFetch.rawValue, arguments: nil, result: { flutterResult in
                    // We got a backgroundFetch result ; let's ensure we can convert it to a native UIBackgroundFetchResult
                    guard
                        let fetchResult: Int = flutterResult as? Int,
                        let backgroundFetchResult = UIBackgroundFetchResult.init(rawValue: UInt(fetchResult))
                        else {
                            completionHandler(.failed)
                            return
                    }
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
