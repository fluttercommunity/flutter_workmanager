//
//  NetworkType.swift
//  workmanager
//
//  Created by Sebastian Roth on 10/06/2021.
//

import Foundation

/// An enumeration of various network types that can be used as Constraints for work.
enum NetworkType: String {
    /// Any working network connection is required for this work.
    case connected

    /// A metered network connection is required for this work.
    case metered

    /// Default value. A network is not required for this work.
    case notRequired

    /// A non-roaming network connection is required for this work.
    case notRoaming

    /// An unmetered network connection is required for this work.
    case unmetered

    /// A temporarily unmetered Network. This capability will be set for 
    /// networks that are generally metered, but are currently unmetered.
    ///
    /// Only applies to Android.
    case temporarilyUnmetered

    /// Convenience constructor to build a [NetworkType] from a Dart enum.
    init?(fromDart: String) {
        self.init(rawValue: fromDart.camelCased(with: "_"))
    }
}

private extension String {
    func camelCased(with separator: Character) -> String {
        return self.lowercased()
            .split(separator: separator)
            .enumerated()
            .map { $0.offset > 0 ? $0.element.capitalized : $0.element.lowercased() }
            .joined()
    }
}
