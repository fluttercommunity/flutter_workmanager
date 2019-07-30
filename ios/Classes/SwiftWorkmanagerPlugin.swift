import Flutter
import UIKit
import os

public class SwiftWorkmanagerPlugin: FlutterPluginAppLifeCycleDelegate {
    
    private struct ForegroundMethodChannel {
        static let channelName = "be.tramckrijte.workmanager/foreground_channel_work_manager"
        enum methods: String {
            case initialize
            case performSampleFetch
        }
    }
    
    private struct BackgroundMethodChannel {
        static let channelName = "be.tramckrijte.workmanager/background_channel_work_manager"
        enum methods: String {
            case backgroundJobDidComplete
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
                result(WMPError.unexpectedMethodArguments(argumentsDescription: call.arguments.debugDescription))
                return
            }
            store(callbackHandle)
            result(nil)
        case ForegroundMethodChannel.methods.performSampleFetch.rawValue:
            triggerSampleBackgroundFetch()
            result(nil)
        default:
            result(WMPError.unhandledMethod(methodName: call.method).asFlutterError)
            return
        }
        
    }
    
}

//MARK: - AppDelegate conformance

extension SwiftWorkmanagerPlugin {
    
    override public func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) -> Bool {
        
        // First, let's retreive our callBack handle
        guard let callbackHandle: Int64 = getStoredCallbackHandle() else {
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
            guard
                call.method == BackgroundMethodChannel.methods.backgroundJobDidComplete.rawValue,
                let argument: UInt = call.arguments as? UInt,
                let backgroundFetchResult = UIBackgroundFetchResult.init(rawValue: argument)
                else {
                    result(WMPError.unexpectedMethodArguments(argumentsDescription: call.arguments.debugDescription))
                    return
            }
            // Method name and arguments match the expected values ; call the native completionHandler
            result(nil)
            completionHandler(backgroundFetchResult)
        }
        
        return true
    }
    
}

//MARK: - Private

private extension SwiftWorkmanagerPlugin {
    
    var callbackHandleStorageKey: String {
        return "callBackHandleStorageKey"
    }
    
    func store(_ callbackHandle: Int64) {
        UserDefaults.standard.set(callbackHandle, forKey: callbackHandleStorageKey)
    }
    
    func getStoredCallbackHandle() -> Int64? {
        return UserDefaults.standard.value(forKey: callbackHandleStorageKey) as? Int64
    }
    
}

private extension SwiftWorkmanagerPlugin {
    
    /// Debug purposes : triggers the native application(_ application: performFetchWithCompletionHandler:) callback (similar to Debug > Simulate Background Fetch)
    func triggerSampleBackgroundFetch() {
        if #available(iOS 10.0, *) {
            os_log("%@", "Debug - handling sample perform fetch")
            let application = UIApplication.shared
            application.delegate?.application?(application, performFetchWithCompletionHandler: { backgroundFetchResult in
                var resultDescription: String {
                    switch backgroundFetchResult {
                    case .newData: return "newData"
                    case .noData: return "noData"
                    case .failed: return "failed"
                    }
                }
                os_log("%@", "Debug - performFetchWithCompletionHandler complete ; result : \(resultDescription)")
            })
        }
    }
    
}
