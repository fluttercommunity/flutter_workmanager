import Flutter
import UIKit

public class SwiftWorkmanagerPlugin: NSObject {
    
    private static let methodChannelName = "workmanager"
    private var methodChannelName: String {
        return type(of: self).methodChannelName
    }
    
    public typealias BackgroundFetchCompletionHandler = (UIBackgroundFetchResult) -> Void
    
    public var backgroundFetchCompletionHandler: BackgroundFetchCompletionHandler?
    private static var methodChannel: FlutterMethodChannel?
    
    private enum FetchResult: Int, CaseIterable {
        case newData = 0
        case noData = 1
        case error = 2
        
        var uiBackgroundFetchResult : UIBackgroundFetchResult {
            switch self {
            case .noData:
                return .noData
            case .newData:
                return .newData
            case .error:
                return .failed
            }
        }
    }
    
    private enum WMPError: Error {
        case methodChannelNotSet
        case backgroundFetchCompletionHandlerNotSet
        case unhandledMethod(methodName: String)
        case unexpectedMethodArguments(argumentsDescription: String)
        
        var code: String {
            return "\(self) error"
        }
        
        var message: String {
            switch self {
            case .methodChannelNotSet:
                return "Method channel not set"
            case .backgroundFetchCompletionHandlerNotSet:
                return "backgroundFetchCompletionHandler not set"
            case .unhandledMethod(let methodName):
                return "Unhandled method \(methodName)"
            case .unexpectedMethodArguments(let argumentsDescription):
                return "Unexpected call arguments \(argumentsDescription)"
            }
        }
        
        var details: Any? {
            return nil
        }
        
        var asFlutterError: FlutterError {
            return FlutterError(code: code, message: message, details: details)
        }
    }
    
}

//MARK: - FlutterPlugin conformance

extension SwiftWorkmanagerPlugin: FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: registrar.messenger())
        let instance = SwiftWorkmanagerPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        self.methodChannel = methodChannel
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == methodChannelName else {
            result(WMPError.unhandledMethod(methodName: call.method).asFlutterError)
            return
        }
        guard
            let flutterFetchResult: Int = call.arguments as? Int,
            let fetchResult = FetchResult.allCases.first(where: { $0.rawValue == flutterFetchResult })
            else {
                result(WMPError.unexpectedMethodArguments(argumentsDescription: String(describing: call.arguments)).asFlutterError)
                return
        }
        guard let completionHandler = self.backgroundFetchCompletionHandler else {
            result(WMPError.backgroundFetchCompletionHandlerNotSet.asFlutterError)
            return
        }
        
        completionHandler(fetchResult.uiBackgroundFetchResult)
    }
}

//MARK: - Fetching

public extension SwiftWorkmanagerPlugin {
    
    func performFetch(_ completionHandler: @escaping BackgroundFetchCompletionHandler) throws {
        guard let methodChannel = type(of: self).methodChannel else {
            throw NSError(domain: type(of: self).description(), code: -1, userInfo: ["Error": "Method channel not set."])
        }
        backgroundFetchCompletionHandler = completionHandler
        methodChannel.invokeMethod(methodChannelName, arguments: nil)
    }
    
}
