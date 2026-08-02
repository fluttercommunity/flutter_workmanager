//
//  WorkmanagerTests.swift
//  WorkmanagerTests
//
//  Created by Sebastian Roth on 08/09/2021.
//  Copyright © 2021 The Chromium Authors. All rights reserved.
//

import XCTest

@testable import workmanager_apple

class WorkmanagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaultsHelper.removeAllScheduledTasks()
    }

    override func tearDown() {
        UserDefaultsHelper.removeAllScheduledTasks()
        super.tearDown()
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
