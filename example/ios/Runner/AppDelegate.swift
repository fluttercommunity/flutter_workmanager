import UIKit
import Flutter
import workmanager
import os

@UIApplicationMain

@objc class AppDelegate: FlutterAppDelegate {
    
    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        GeneratedPluginRegistrant.register(with: self)
        
        let registrar: FlutterPluginRegistrar = self.registrar(forPlugin: "DoesntMatter")
        let messenger: FlutterBinaryMessenger = registrar.messenger()
        let methodChannel: FlutterMethodChannel = FlutterMethodChannel(name: "be.tramckrijte.workmanager/registration", binaryMessenger: messenger)
        methodChannel.setMethodCallHandler { (call, result) in
            os_log("%@", "Registration channel - did receive call \(call.method)")
            result(true)
        }
        
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        
    }
    
}
