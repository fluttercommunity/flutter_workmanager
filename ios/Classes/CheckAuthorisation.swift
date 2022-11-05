//
//  CheckAuthorisation.swift
//  workmanager
//
//  Created by Lars Huth on 03/11/2022.
//
import Foundation

func checkBackgroundRefreshAuthorisation(result:@escaping FlutterResult) -> BackgroundAuthorisationState{
    switch UIApplication.shared.backgroundRefreshStatus {
    case .available:
        result(BackgroundAuthorisationState.available.rawValue)
        return BackgroundAuthorisationState.available
    case .denied:
        result(BackgroundAuthorisationState.denied.rawValue)
        return BackgroundAuthorisationState.denied
    case .restricted:
        result(BackgroundAuthorisationState.restricted.rawValue)
        return BackgroundAuthorisationState.restricted
    default:
        result(
            FlutterError(
                code: "103",
                message: "BGAppRefreshTask - You have no iOS background refresh permissions. " +
                "\n" +
                "BackgroundRefreshStatus is denied\n" +
                "\n" +
                "Workmanager asked on initialize function for background permissions - when user accepted this you can set a periodic background task",
                details: nil
            )
        )
        return BackgroundAuthorisationState.unknown
    }
}

func requestBackgroundAuthorisation(){
    //request for authorisation
    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
}

enum BackgroundAuthorisationState:String
{
    /// iOS Setting Backgroundwork is enabled.
    case available
    
    /// iOS Setting Backgroundwork is disabled in settings. You shoud request for permissions call requestBackgroundAuthorisation only once and respect users choice
    case denied
    
    /// iOS Setting is under parental control etc. Can't be changed by user
    case restricted
    
    /// unknown state
    case unknown
    
    /// Convenience constructor to build a [BackgroundAutorisationState] from a Dart enum.
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
