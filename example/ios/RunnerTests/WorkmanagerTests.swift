//
//  WorkmanagerTests.swift
//  WorkmanagerTests
//
//  Created by Sebastian Roth on 08/09/2021.
//  Copyright © 2021 The Chromium Authors. All rights reserved.
//

import XCTest

@testable import workmanager

class WorkmanagerTests: XCTestCase {

    func testNetworkType() throws {
        XCTAssertEqual(NetworkType.connected, NetworkType(fromDart: "connected"))
        XCTAssertEqual(NetworkType.metered, NetworkType(fromDart: "metered"))
        XCTAssertEqual(NetworkType.notRequired, NetworkType(fromDart: "not_required"))
        XCTAssertEqual(NetworkType.notRoaming, NetworkType(fromDart: "not_roaming"))
        XCTAssertEqual(NetworkType.temporarilyUnmetered, NetworkType(fromDart: "temporarily_unmetered"))
        XCTAssertEqual(NetworkType.unmetered, NetworkType(fromDart: "unmetered"))
    }

}
