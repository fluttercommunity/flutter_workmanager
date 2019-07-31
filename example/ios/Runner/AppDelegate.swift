import UIKit
import Flutter
import workmanager

@UIApplicationMain

@objc class AppDelegate: FlutterAppDelegate {
    
    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        SwiftWorkmanagerPlugin.clearStorage()
        
        GeneratedPluginRegistrant.register(with: self)
        let registrar = self.registrar(forPlugin: "SamplePlugin")
        SamplePlugin.register(with: registrar)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
}

class SamplePlugin: NSObject, FlutterPlugin {
    
    private static let methodChannelName = "iOSMethodChannel"   // Note : this must stay in sync with the Flutter Example project
    private let methodName = "iOSPerformFetch"                  // Note : this must stay in sync with the Flutter Example project
    
    static func register(with registrar: FlutterPluginRegistrar) {
        
        let iOSMethodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: registrar.messenger())
        let instance = SamplePlugin()
        registrar.addMethodCallDelegate(instance, channel: iOSMethodChannel)
        registrar.addApplicationDelegate(instance)
        
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        guard call.method == methodName else {
            result(FlutterError(code: "-1", message: "Unexpected call method \(call.method)", details: nil))
            return
        }
        let application = UIApplication.shared
        application.delegate?.application?(application, performFetchWithCompletionHandler: { backgroundFetchResult in
            self.presentBackgroundFetchResultAlert(on: application.keyWindow?.rootViewController, backgroundFetchResult: backgroundFetchResult)
        })
        
    }
    
    func presentBackgroundFetchResultAlert(on viewController: UIViewController?, backgroundFetchResult: UIBackgroundFetchResult) {
        
        var backgroundFetchResultDescription: String {
            switch backgroundFetchResult {
            case .newData: return "Success - new data available"
            case .noData: return "Success - no new data"
            case .failed: return "Failed"
            }
        }
        let alert = UIAlertController(title: "Background fetch complete", message: "Result : \(backgroundFetchResultDescription)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        DispatchQueue.main.async {
            viewController?.present(alert, animated: true, completion: nil)
        }
    }
    
}
