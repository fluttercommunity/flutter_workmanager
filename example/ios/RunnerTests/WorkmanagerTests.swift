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

}
