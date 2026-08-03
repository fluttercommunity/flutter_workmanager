//
//  WorkmanagerTests.swift
//  WorkmanagerTests
//
//  Created by Sebastian Roth on 08/09/2021.
//  Copyright © 2021 The Chromium Authors. All rights reserved.
//

import XCTest
import Flutter

@testable import workmanager_apple

/// Minimal `FlutterBinaryMessenger` stub that records outgoing channel messages
/// and replies with pigeon-encoded success payloads, simulating the Dart side
/// of the workmanager Flutter API.
private final class MockBinaryMessenger: NSObject, FlutterBinaryMessenger {
    private let codec = WorkmanagerApiPigeonCodec.shared
    private(set) var sentChannels: [String] = []

    /// When set, the reply sent for the `backgroundChannelInitialized` call is
    /// a pigeon error instead of success (simulating an unregistered handler).
    var failBackgroundChannelInitialized = false

    func send(onChannel channel: String, message: Data?) {
        sentChannels.append(channel)
    }

    func send(
        onChannel channel: String,
        message: Data?,
        binaryReply reply: FlutterBinaryReply?
    ) {
        sentChannels.append(channel)

        let response: Any
        if channel.contains("backgroundChannelInitialized") {
            response = failBackgroundChannelInitialized
                ? ["99", "No handler registered", nil] as [Any?]
                : [] as [Any]
        } else {
            response = [true]
        }
        reply?(codec.encode(response))
    }

    func setMessageHandlerOnChannel(
        _ channel: String,
        binaryMessageHandler handler: FlutterBinaryMessageHandler?
    ) -> FlutterBinaryMessengerConnection {
        return 0
    }

    func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}

class WorkmanagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkmanagerPlugin.mainBinaryMessenger = nil
        UserDefaultsHelper.removeAllScheduledTasks()
    }

    override func tearDown() {
        WorkmanagerPlugin.mainBinaryMessenger = nil
        UserDefaultsHelper.removeAllScheduledTasks()
        super.tearDown()
    }

    // MARK: - In-process one-off task execution (#653)

    func testOneOffTaskExecutesOnMainEngineWhenMessengerIsAvailable() {
        let messenger = MockBinaryMessenger()
        WorkmanagerPlugin.mainBinaryMessenger = messenger

        WorkmanagerPlugin.startOneOffTask(
            identifier: "dev.fluttercommunity.test.oneOff",
            taskIdentifier: .invalid,
            inputData: ["key": "value"],
            delaySeconds: 0
        )

        XCTAssertEqual(
            messenger.sentChannels,
            [
                "dev.flutter.pigeon.workmanager_platform_interface.WorkmanagerFlutterApi.backgroundChannelInitialized",
                "dev.flutter.pigeon.workmanager_platform_interface.WorkmanagerFlutterApi.executeTask"
            ]
        )
    }

    func testOneOffTaskFallsBackToHeadlessEngineWhenDartHandlerIsNotReady() {
        let messenger = MockBinaryMessenger()
        messenger.failBackgroundChannelInitialized = true
        WorkmanagerPlugin.mainBinaryMessenger = messenger

        WorkmanagerPlugin.startOneOffTask(
            identifier: "dev.fluttercommunity.test.oneOffFallback",
            taskIdentifier: .invalid,
            inputData: nil,
            delaySeconds: 0
        )

        // The in-process path must not execute the task; the headless engine
        // fallback handles it instead (and does not use the main messenger).
        XCTAssertEqual(
            messenger.sentChannels,
            [
                "dev.flutter.pigeon.workmanager_platform_interface.WorkmanagerFlutterApi.backgroundChannelInitialized"
            ]
        )
    }

    // MARK: - Scheduled task persistence (BGTask launch-handler re-registration)

    func testScheduledTaskRoundTripPreservesKindAndEarliestBegin() {
        let identifier = "dev.fluttercommunity.test.roundTrip"
        let task = ScheduledTaskInfo(kind: .processing, earliestBeginInSeconds: 120)

        UserDefaultsHelper.storeScheduledTask(task, forTaskIdentifier: identifier)

        let stored = UserDefaultsHelper.getScheduledTasks()[identifier]
        XCTAssertNotNil(stored, "stored task should be retrievable")
        XCTAssertEqual(stored?.kind, .processing)
        XCTAssertEqual(stored?.earliestBeginInSeconds, 120)
    }

    func testScheduledTaskStoresNilEarliestBeginForRefreshTasks() {
        let identifier = "dev.fluttercommunity.test.nilEarliestBegin"
        UserDefaultsHelper.storeScheduledTask(
            ScheduledTaskInfo(kind: .refresh, earliestBeginInSeconds: nil),
            forTaskIdentifier: identifier
        )

        let stored = UserDefaultsHelper.getScheduledTasks()[identifier]
        XCTAssertNotNil(stored, "stored task should be retrievable")
        XCTAssertEqual(stored?.kind, .refresh)
        XCTAssertNil(stored?.earliestBeginInSeconds)
    }

    func testScheduledTaskRoundTripPreservesContinuedProcessingKind() {
        let identifier = "dev.fluttercommunity.test.continuedProcessing"
        UserDefaultsHelper.storeScheduledTask(
            ScheduledTaskInfo(kind: .continuedProcessing, earliestBeginInSeconds: nil),
            forTaskIdentifier: identifier
        )

        let stored = UserDefaultsHelper.getScheduledTasks()[identifier]
        XCTAssertNotNil(stored, "stored task should be retrievable")
        XCTAssertEqual(stored?.kind, .continuedProcessing)
        XCTAssertNil(stored?.earliestBeginInSeconds)
    }

    func testRemoveScheduledTaskOnlyRemovesMatchingIdentifier() {
        let keepIdentifier = "dev.fluttercommunity.test.keep"
        let removeIdentifier = "dev.fluttercommunity.test.remove"
        UserDefaultsHelper.storeScheduledTask(
            ScheduledTaskInfo(kind: .refresh, earliestBeginInSeconds: nil),
            forTaskIdentifier: keepIdentifier
        )
        UserDefaultsHelper.storeScheduledTask(
            ScheduledTaskInfo(kind: .processing, earliestBeginInSeconds: 60),
            forTaskIdentifier: removeIdentifier
        )

        UserDefaultsHelper.removeScheduledTask(removeIdentifier)

        XCTAssertNil(UserDefaultsHelper.getScheduledTasks()[removeIdentifier])
        XCTAssertNotNil(UserDefaultsHelper.getScheduledTasks()[keepIdentifier])
    }

    func testRemoveAllScheduledTasksClearsPersistedState() {
        UserDefaultsHelper.storeScheduledTask(
            ScheduledTaskInfo(kind: .refresh, earliestBeginInSeconds: nil),
            forTaskIdentifier: "dev.fluttercommunity.test.clear"
        )

        UserDefaultsHelper.removeAllScheduledTasks()

        XCTAssertTrue(UserDefaultsHelper.getScheduledTasks().isEmpty)
    }

    // MARK: - WorkInfoStore (persisted task state for the query API)

    func testPersistedWorkInfoRoundTrip() {
        let uniqueName = "dev.fluttercommunity.test.workInfoRoundTrip"
        let now = Date().timeIntervalSince1970

        UserDefaultsHelper.storeWorkInfo(
            PersistedWorkInfo(
                state: "scheduled",
                isPeriodic: true,
                taskName: "dart-task",
                lastFinishedAt: nil,
                updatedAt: now
            ),
            forUniqueName: uniqueName
        )

        let stored = UserDefaultsHelper.getWorkInfo(forUniqueName: uniqueName)
        XCTAssertNotNil(stored, "stored work info should be retrievable")
        XCTAssertEqual(stored?.state, "scheduled")
        XCTAssertEqual(stored?.isPeriodic, true)
        XCTAssertEqual(stored?.taskName, "dart-task")
        XCTAssertNil(stored?.lastFinishedAt)
        XCTAssertEqual(stored?.updatedAt, now)
    }

    func testWorkInfoStoreTracksStatusTransitions() {
        let uniqueName = "dev.fluttercommunity.test.transitions"

        // Registration.
        WorkInfoStore.record(
            taskInfo: TaskDebugInfo(
                taskName: "dart-task",
                uniqueName: uniqueName,
                startTime: Date().timeIntervalSince1970,
                isPeriodic: true
            ),
            status: .scheduled,
            result: nil,
            isPeriodic: true
        )
        // Execution started.
        WorkInfoStore.record(
            taskInfo: TaskDebugInfo(
                taskName: "dart-task",
                uniqueName: uniqueName,
                startTime: Date().timeIntervalSince1970
            ),
            status: .started,
            result: nil,
            isPeriodic: nil
        )
        // Completed successfully.
        WorkInfoStore.record(
            taskInfo: TaskDebugInfo(
                taskName: "dart-task",
                uniqueName: uniqueName,
                startTime: Date().timeIntervalSince1970
            ),
            status: .completed,
            result: TaskResult(success: true, duration: 100),
            isPeriodic: nil
        )

        let data = WorkInfoStore.workInfoData(forUniqueName: uniqueName)
        XCTAssertNotNil(data, "query should return a snapshot")
        XCTAssertEqual(data?.uniqueName, uniqueName)
        XCTAssertEqual(data?.state, .succeeded)
        XCTAssertEqual(data?.isPeriodic, true, "isPeriodic survives execution updates")
        XCTAssertEqual(data?.taskName, "dart-task", "taskName survives execution updates")
        XCTAssertNotNil(data?.lastFinishedAtMillis)
    }

    func testWorkInfoStoreResolvesUniqueNameByTaskNameForOneOffTasks() {
        // iOS one-off tasks execute under their registered taskName (the
        // identifier); the store resolves the uniqueName via the persisted
        // registration record.
        let uniqueName = "dev.fluttercommunity.test.oneOffUnique"
        WorkInfoStore.record(
            taskInfo: TaskDebugInfo(
                taskName: "one-off-task",
                uniqueName: uniqueName,
                startTime: Date().timeIntervalSince1970,
                isPeriodic: false
            ),
            status: .scheduled,
            result: nil,
            isPeriodic: false
        )
        // Execution update carries only the taskName (the identifier).
        WorkInfoStore.record(
            taskInfo: TaskDebugInfo(
                taskName: "one-off-task",
                uniqueName: nil,
                startTime: Date().timeIntervalSince1970
            ),
            status: .started,
            result: nil,
            isPeriodic: nil
        )

        let data = WorkInfoStore.workInfoData(forUniqueName: uniqueName)
        XCTAssertEqual(data?.state, .running)
    }

    func testWorkInfoStoreRetryingMapsToScheduledWithFinishTime() {
        let uniqueName = "dev.fluttercommunity.test.retry"
        WorkInfoStore.record(
            taskInfo: TaskDebugInfo(
                taskName: "t",
                uniqueName: uniqueName,
                startTime: Date().timeIntervalSince1970,
                isPeriodic: false
            ),
            status: .scheduled,
            result: nil,
            isPeriodic: false
        )
        WorkInfoStore.record(
            taskInfo: TaskDebugInfo(
                taskName: "t",
                uniqueName: uniqueName,
                startTime: Date().timeIntervalSince1970
            ),
            status: .retrying,
            result: TaskResult(success: false, duration: 100),
            isPeriodic: nil
        )

        let data = WorkInfoStore.workInfoData(forUniqueName: uniqueName)
        XCTAssertEqual(data?.state, .scheduled)
        XCTAssertNotNil(data?.lastFinishedAtMillis)
    }

    func testWorkInfoStoreCancellationMarksTheTaskCancelled() {
        let uniqueName = "dev.fluttercommunity.test.cancel"
        WorkInfoStore.record(
            taskInfo: TaskDebugInfo(
                taskName: "t",
                uniqueName: uniqueName,
                startTime: Date().timeIntervalSince1970,
                isPeriodic: false
            ),
            status: .scheduled,
            result: nil,
            isPeriodic: false
        )

        WorkInfoStore.markCancelled(uniqueName: uniqueName)

        let data = WorkInfoStore.workInfoData(forUniqueName: uniqueName)
        XCTAssertEqual(data?.state, .cancelled)
        XCTAssertNotNil(data?.lastFinishedAtMillis)
    }

    func testWorkInfoStoreUnknownTaskReturnsNil() {
        XCTAssertNil(
            WorkInfoStore.workInfoData(forUniqueName: "dev.fluttercommunity.test.unknown")
        )
    }

}
