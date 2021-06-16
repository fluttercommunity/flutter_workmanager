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
    case not_required

    /// A non-roaming network connection is required for this work.
    case not_roaming

    /// An unmetered network connection is required for this work.
    case unmetered

}
