#if os(macOS)

import Foundation

/// Manages NSBackgroundActivityScheduler instances for macOS.
///
/// iOS uses BGTaskScheduler (managed by the OS). macOS has no BGTaskScheduler:
/// NSBackgroundActivityScheduler is the equivalent, and it only fires while the
/// app process is alive and the Mac is awake. This class keeps a registry of
/// scheduled activities keyed by the task's unique name so they can be
/// cancelled and inspected.
final class MacOSActivityScheduler {

    static let shared = MacOSActivityScheduler()

    private let registryLock = NSLock()
    private var scheduledActivities: [String: NSBackgroundActivityScheduler] = [:]

    private init() {}

    /// Schedules a task with NSBackgroundActivityScheduler.
    ///
    /// - Parameters:
    ///   - uniqueName: Unique task identifier (also used as the activity identifier).
    ///   - isPeriodic: `true` for repeating activities, `false` for one-off tasks.
    ///   - interval: For one-off tasks this is the delay before the run; for
    ///     periodic tasks it is the repeat interval in seconds.
    ///   - inputData: Input data passed from the Dart side.
    ///   - flutterPluginRegistrantCallback: Callback that registers plugins on
    ///     the headless engine used to execute the task.
    func scheduleActivity(
        uniqueName: String,
        isPeriodic: Bool,
        interval: TimeInterval,
        inputData: [String: Any]?,
        flutterPluginRegistrantCallback: WMPFlutterPluginRegistrantCallback?
    ) {
        let activity = NSBackgroundActivityScheduler(identifier: uniqueName)
        activity.repeats = isPeriodic
        // NSBackgroundActivityScheduler raises an exception for interval or
        // tolerance values <= 0, so clamp to a positive minimum.
        activity.interval = max(interval, 1)
        if isPeriodic {
            activity.tolerance = max(activity.interval * 0.2, 1)
        }
        activity.qualityOfService = .utility

        activity.schedule { completion in
            logInfo("[NSBackgroundActivityScheduler] Activity fired: \(uniqueName)")

            let worker = BackgroundWorker(
                mode: isPeriodic
                    ? .backgroundPeriodicTask(identifier: uniqueName)
                    : .backgroundOneOffTask(identifier: uniqueName),
                inputData: inputData,
                flutterPluginRegistrantCallback: flutterPluginRegistrantCallback
            )

            // Flutter engine operations must happen on the main thread.
            DispatchQueue.main.async {
                worker.performBackgroundRequest { result in
                    logInfo(
                        "[NSBackgroundActivityScheduler] Activity \(uniqueName) finished with \(result.debugDescription)"
                    )
                    completion(.finished)
                }
            }
        }

        registryLock.lock()
        scheduledActivities[uniqueName]?.invalidate()
        scheduledActivities[uniqueName] = activity
        registryLock.unlock()

        logInfo(
            "[NSBackgroundActivityScheduler] Scheduled \(isPeriodic ? "periodic" : "one-off") activity " +
                "\(uniqueName) interval: \(activity.interval)s"
        )
    }

    /// Runs a one-off task immediately on the main thread.
    ///
    /// Mirrors the iOS behavior where one-off tasks are started right away
    /// (`beginBackgroundTask` + operation queue) instead of being deferred to
    /// the system scheduler. NSBackgroundActivityScheduler is opportunistic and
    /// can delay "as soon as possible" runs, so tasks with no initial delay
    /// execute directly while the app is running.
    func runOneOffTaskNow(
        uniqueName: String,
        taskName: String,
        inputData: [String: Any]?,
        flutterPluginRegistrantCallback: WMPFlutterPluginRegistrantCallback?
    ) {
        let worker = BackgroundWorker(
            mode: .backgroundOneOffTask(identifier: uniqueName),
            inputData: inputData,
            flutterPluginRegistrantCallback: flutterPluginRegistrantCallback
        )
        DispatchQueue.main.async {
            worker.performBackgroundRequest { result in
                logInfo("[workmanager] one-off task \(uniqueName) finished with \(result.debugDescription)")
            }
        }
    }

    func cancel(uniqueName: String) {
        registryLock.lock()
        scheduledActivities.removeValue(forKey: uniqueName)?.invalidate()
        registryLock.unlock()
    }

    func cancelAll() {
        registryLock.lock()
        let activities = Array(scheduledActivities.values)
        scheduledActivities.removeAll()
        registryLock.unlock()
        activities.forEach { $0.invalidate() }
    }

    func isScheduled(uniqueName: String) -> Bool {
        registryLock.lock()
        let scheduled = scheduledActivities[uniqueName] != nil
        registryLock.unlock()
        return scheduled
    }

    func printScheduledActivities() -> String {
        registryLock.lock()
        let activities = Array(scheduledActivities.values)
        registryLock.unlock()

        if activities.isEmpty {
            let message = "[NSBackgroundActivityScheduler] There are no scheduled activities"
            log(message)
            return message
        }

        var message = "[NSBackgroundActivityScheduler] Scheduled Activities:"
        for activity in activities {
            message += "\n[NSBackgroundActivityScheduler] Activity Identifier: \(activity.identifier) interval: \(activity.interval)s repeats: \(activity.repeats)"
        }
        log("\(message)")
        return message
    }
}

#endif
