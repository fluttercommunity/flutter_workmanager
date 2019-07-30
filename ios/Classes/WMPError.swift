//
//  WMPError.swift
//  workmanager
//
//  Created by Jérémie Vincke on 30/07/2019.
//

import Foundation

enum WMPError: Error {
    case methodChannelNotSet
    case unhandledMethod(methodName: String)
    case unexpectedMethodArguments(argumentsDescription: String)
    
    var code: String {
        return "\(self) error"
    }
    
    var message: String {
        switch self {
        case .methodChannelNotSet:
            return "Method channel not set"
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
