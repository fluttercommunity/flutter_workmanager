//
//  SimpleLogger.swift
//
//  Created by Kymer Gryson on 15/11/2018.
//

import Foundation
import os

/// Thin wrapper around `OSLogType`
enum LogType: String {
    
    /// Use this level to capture information about things that might result a failure.
    case `default` = "default"
    
    /// Use this level to capture information that may be helpful, but isn’t essential, for troubleshooting errors.
    case info = "info"
    
    /// Use this level to capture information that may be useful during development or while troubleshooting a specific problem.
    case debug = "debug"
    
    /// Use this log level to capture process-level information to report errors in the process.
    case error = "error"
    
    /// Use this level to capture system-level or multi-process information to report system errors.
    case fault = "fault"
    
    /// Returns the underlying `OSLogType`
    var osLogType: OSLogType {
        switch self {
        case .default:
            return OSLogType.default
        case .info:
            return OSLogType.info
        case .debug:
            return OSLogType.debug
        case .error:
            return OSLogType.error
        case .fault:
            return OSLogType.fault
        }
    }
}

func log(_ message: String) {
    log(message, as: .default)
}

func logInfo(_ message: String) {
    log(message, as: .info)
}

func logDebug(_ message: String) {
    log(message, as: .debug)
}

func logError(_ message: String) {
    log(message, as: .error)
}

func logFault(_ message: String) {
    log(message, as: .fault)
}

func log(_ message: String, as type: LogType = .default) {
    
    if #available(iOS 10.0, *) {
        os_log("%@", type: type.osLogType, message)
    } else {
        NSLog("%@", "\(type.rawValue) log: \(message)")
    }
    
}
