//
//  CheckBackgroundRefreshPermission.swift
//  workmanager
//
//  Created by Lars Huth on 03/11/2022.
//
import Foundation

func checkBackgroundRefreshPermission(result: @escaping FlutterResult) -> BackgroundRefreshPermissionState {
    switch UIApplication.shared.backgroundRefreshStatus {
    case .available:
        result(BackgroundRefreshPermissionState.available.rawValue)
        return BackgroundRefreshPermissionState.available
    case .denied:
        result(BackgroundRefreshPermissionState.denied.rawValue)
        return BackgroundRefreshPermissionState.denied
    case .restricted:
        result(BackgroundRefreshPermissionState.restricted.rawValue)
        return BackgroundRefreshPermissionState.restricted
    default:
        result(
            FlutterError(
                code: "103",
                message: "BGAppRefreshTask - Probably you have restricted background refresh permission. " +
                "\n" +
                "BackgroundRefreshStatus is unknown\n",
                details: nil
            )
        )
        return BackgroundRefreshPermissionState.unknown
    }
}

func requestBackgroundPermission() {
    // Request for permission
    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
}

enum BackgroundRefreshPermissionState: String {
    /// Background app refresh is enabled in iOS Setting
    case available

    /// Background app refresh is disabled in iOS Setting. Permission should be requested from user
    case denied

    /// iOS Setting is under parental control etc. Can't be changed by user
    case restricted

    /// Unknown state
    case unknown

    /// Convenience constructor to build a [BackgroundRefreshPermissionState] from a Dart enum.
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
