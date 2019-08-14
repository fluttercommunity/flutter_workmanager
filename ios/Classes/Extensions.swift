//
//  Extensions.swift
//  workmanager
//
//  Created by Kymer Gryson on 13/08/2019.
//

import Foundation

extension UIBackgroundFetchResult: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .newData:
            return "newData"
        case .noData:
            return "noData"
        case .failed:
            return "failed"
        }
    }
}

internal extension Date {
    func formatted() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        return formatter.string(from: self)
    }
}

internal extension TimeInterval {
    func formatToSeconds() -> String {
        return "\(String(format: "%.2f", self)) seconds"
    }
}
