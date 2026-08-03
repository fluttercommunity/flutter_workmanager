import Foundation

/// Persists the plugin's own view of task state on Apple platforms and serves
/// the `getWorkInfo` query from it.
///
/// **Why this exists**: BGTaskScheduler (iOS) and NSBackgroundActivityScheduler
/// (macOS) have **no query API** — there is no way to ask the system "what is
/// the state of this task?". Rather than telling the Flutter engineer "you
/// can't know", the plugin records every task-status transition it observes
/// (registration, start, completion, failure, cancellation) into UserDefaults
/// and answers queries from that store.
///
/// The result is intentionally best-effort and documented as such: it reflects
/// what the plugin has seen, not the system scheduler's view. For example iOS
/// may prune pending BGTaskScheduler requests without informing the app; the
/// store would still report the task as `scheduled`.
enum WorkInfoStore {

    /// Records a task-status transition observed by the plugin.
    ///
    /// - Parameters:
    ///   - taskInfo: Debug info for the transition. `uniqueName` keys the
    ///     store; when it is nil (iOS one-off tasks execute under their
    ///     registered `taskName`), the record is resolved by `taskName`, which
    ///     the registration step always persisted.
    ///   - status: The observed status.
    ///   - result: Result of the run, when the transition ended a run.
    ///   - isPeriodic: Whether the task is periodic; only the registration
    ///     sites know this for certain, so nil keeps the recorded value.
    static func record(taskInfo: TaskDebugInfo, status: TaskStatus, result: TaskResult?, isPeriodic: Bool?) {
        guard let uniqueName = resolveUniqueName(taskInfo: taskInfo) else {
            return
        }
        let existing = UserDefaultsHelper.getWorkInfo(forUniqueName: uniqueName)
        let now = Date().timeIntervalSince1970

        let state: String
        var lastFinishedAt = existing?.lastFinishedAt
        switch status {
        case .scheduled:
            state = "scheduled"
        case .started:
            state = "running"
        case .completed:
            state = "succeeded"
            lastFinishedAt = now
        case .failed:
            state = "failed"
            lastFinishedAt = now
        case .cancelled:
            state = "cancelled"
            lastFinishedAt = now
        case .retrying, .rescheduled:
            // The attempt ended without success and the task is expected to
            // run again; report it as scheduled with the attempt's finish time.
            state = "scheduled"
            lastFinishedAt = now
        }

        // The registration step is the only place that carries the
        // user-facing taskName; execution updates (which report the scheduler
        // identifier) must not overwrite it.
        let resolvedTaskName: String?
        if status == .scheduled {
            resolvedTaskName = taskInfo.taskName
        } else {
            resolvedTaskName = existing?.taskName ?? taskInfo.taskName
        }

        UserDefaultsHelper.storeWorkInfo(
            PersistedWorkInfo(
                state: state,
                isPeriodic: isPeriodic ?? existing?.isPeriodic ?? false,
                taskName: resolvedTaskName,
                lastFinishedAt: lastFinishedAt,
                updatedAt: now
            ),
            forUniqueName: uniqueName
        )
    }

    /// Marks a task as cancelled. Used by `cancelByUniqueName` / `cancelAll`,
    /// which do not emit status events. Kept (like WorkManager keeps CANCELLED
    /// work) so queries still find the task and report `cancelled`.
    static func markCancelled(uniqueName: String) {
        guard var info = UserDefaultsHelper.getWorkInfo(forUniqueName: uniqueName) else {
            return
        }
        let now = Date().timeIntervalSince1970
        info.state = "cancelled"
        info.lastFinishedAt = now
        info.updatedAt = now
        UserDefaultsHelper.storeWorkInfo(info, forUniqueName: uniqueName)
    }

    /// Marks every recorded task as cancelled (used by `cancelAll`).
    static func markAllCancelled() {
        let infos = UserDefaultsHelper.getAllWorkInfos()
        let now = Date().timeIntervalSince1970
        for (uniqueName, var info) in infos {
            info.state = "cancelled"
            info.lastFinishedAt = now
            info.updatedAt = now
            UserDefaultsHelper.storeWorkInfo(info, forUniqueName: uniqueName)
        }
    }

    /// Returns the query snapshot for [uniqueName], or nil when the plugin has
    /// no record of the task.
    static func workInfoData(forUniqueName uniqueName: String) -> WorkInfoData? {
        guard let info = UserDefaultsHelper.getWorkInfo(forUniqueName: uniqueName) else {
            return nil
        }
        let state: WorkState
        switch info.state {
        case "scheduled": state = .scheduled
        case "running": state = .running
        case "succeeded": state = .succeeded
        case "failed": state = .failed
        case "cancelled": state = .cancelled
        default: state = .scheduled
        }
        return WorkInfoData(
            uniqueName: uniqueName,
            state: state,
            isPeriodic: info.isPeriodic,
            taskName: info.taskName,
            tags: nil,
            lastFinishedAtMillis: info.lastFinishedAt.map { Int64($0 * 1000) }
        )
    }

    // MARK: - Private

    /// iOS one-off tasks report their execution under the registered taskName
    /// (the `identifier`), while the store is keyed by uniqueName. Resolve the
    /// key from the most recently updated record with that taskName.
    private static func resolveUniqueName(taskInfo: TaskDebugInfo) -> String? {
        if let uniqueName = taskInfo.uniqueName {
            return uniqueName
        }
        // taskName is non-optional on TaskDebugInfo; iOS one-off tasks carry
        // their registered taskName here.
        let taskName = taskInfo.taskName
        return UserDefaultsHelper.getAllWorkInfos()
            .filter { $0.value.taskName == taskName }
            .max { $0.value.updatedAt < $1.value.updatedAt }?
            .key
    }
}
