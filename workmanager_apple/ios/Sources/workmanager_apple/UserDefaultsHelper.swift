//
//  WorkmanagerUserDefaultsHelper.swift
//  workmanager
//
//  Created by Kymer Gryson on 13/08/2019.
//

import Foundation

struct UserDefaultsHelper {

    // MARK: Properties

    private static let userDefaults = UserDefaults(suiteName: "\(WorkmanagerPlugin.identifier).userDefaults")!

    enum Key {
        case callbackHandle
        case periodicTaskInputData(taskIdentifier: String)

        var stringValue: String {
            switch self {
            case .callbackHandle:
                return "\(WorkmanagerPlugin.identifier).callbackHandle"
            case .periodicTaskInputData(let taskIdentifier):
                return "\(WorkmanagerPlugin.identifier).periodicTaskInputData.\(taskIdentifier)"
            }
        }
    }

    // MARK: callbackHandle

    static func storeCallbackHandle(_ handle: Int64) {
       store(handle, key: .callbackHandle)
    }

    static func getStoredCallbackHandle() -> Int64? {
        return getValue(for: .callbackHandle)
    }

    // MARK: periodicTaskInputData

    static func storePeriodicTaskInputData(_ inputData: [String: Any]?, forTaskIdentifier taskIdentifier: String) {
        let key = Key.periodicTaskInputData(taskIdentifier: taskIdentifier)
        if let inputData = inputData {
            store(inputData, key: key)
        } else {
            // Storing nil crashes UserDefaults (NSInvalidArgumentException),
            // and re-registering without inputData should drop stale data.
            userDefaults.removeObject(forKey: key.stringValue)
        }
    }

    static func getStoredPeriodicTaskInputData(forTaskIdentifier taskIdentifier: String) -> [String: Any]? {
        return getValue(for: .periodicTaskInputData(taskIdentifier: taskIdentifier))
    }

    // MARK: Private helper functions

    private static func store<T>(_ value: T, key: Key) {
        userDefaults.setValue(value, forKey: key.stringValue)
    }

    private static func getValue<T>(for key: Key) -> T? {
        return userDefaults.value(forKey: key.stringValue) as? T
    }

}
