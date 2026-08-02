//
//  WorkmanagerUserDefaultsHelper.swift
//  workmanager
//
//  Created by Kymer Gryson on 13/08/2019.
//

import Foundation

/// The kind of BGTaskScheduler task a scheduled identifier refers to.
enum ScheduledTaskKind: String, Codable {
    case refresh
    case processing
    case healthResearch
}

/// Metadata persisted for a scheduled BGTask identifier so launch handlers
/// can be re-registered on the next app launch (required by BGTaskScheduler
/// before a task can be delivered to a relaunched app).
struct ScheduledTaskInfo: Codable {
    let kind: ScheduledTaskKind
    let earliestBeginInSeconds: Double?
}

struct UserDefaultsHelper {

    // MARK: Properties

    private static let userDefaults = UserDefaults(suiteName: "\(WorkmanagerPlugin.identifier).userDefaults")!

    enum Key {
        case callbackHandle
        case periodicTaskInputData(taskIdentifier: String)
        case scheduledTasks

        var stringValue: String {
            switch self {
            case .callbackHandle:
                return "\(WorkmanagerPlugin.identifier).callbackHandle"
            case .periodicTaskInputData(let taskIdentifier):
                return "\(WorkmanagerPlugin.identifier).periodicTaskInputData.\(taskIdentifier)"
            case .scheduledTasks:
                return "\(WorkmanagerPlugin.identifier).scheduledTasks"
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

    // MARK: Scheduled BGTask identifiers

    static func storeScheduledTask(_ task: ScheduledTaskInfo, forTaskIdentifier taskIdentifier: String) {
        var tasks = getScheduledTasks()
        tasks[taskIdentifier] = task
        if let data = try? JSONEncoder().encode(tasks) {
            userDefaults.set(data, forKey: Key.scheduledTasks.stringValue)
        }
    }

    static func getScheduledTasks() -> [String: ScheduledTaskInfo] {
        guard let data = userDefaults.data(forKey: Key.scheduledTasks.stringValue),
              let tasks = try? JSONDecoder().decode([String: ScheduledTaskInfo].self, from: data)
        else {
            return [:]
        }
        return tasks
    }

    static func removeScheduledTask(_ taskIdentifier: String) {
        var tasks = getScheduledTasks()
        if tasks.removeValue(forKey: taskIdentifier) != nil {
            if let data = try? JSONEncoder().encode(tasks) {
                userDefaults.set(data, forKey: Key.scheduledTasks.stringValue)
            }
        }
    }

    static func removeAllScheduledTasks() {
        userDefaults.removeObject(forKey: Key.scheduledTasks.stringValue)
    }

    // MARK: Private helper functions

    private static func store<T>(_ value: T, key: Key) {
        userDefaults.setValue(value, forKey: key.stringValue)
    }

    private static func getValue<T>(for key: Key) -> T? {
        return userDefaults.value(forKey: key.stringValue) as? T
    }

}
