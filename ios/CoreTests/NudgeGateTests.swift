//
//  NudgeGateTests.swift — pins the reach-out rules (off by default, barely ever).
//

import XCTest
@testable import LuminousCore

final class NudgeGateTests: XCTestCase {

    private func input(enabled: Bool = true, quietStart: Int = 23, quietEnd: Int = 8,
                       maxPerDay: Int = 3, sentToday: Int = 0, hour: Int = 15) -> NudgeGate.Input {
        NudgeGate.Input(nudgesEnabled: enabled, quietStart: quietStart, quietEnd: quietEnd,
                        maxPerDay: maxPerDay, sentToday: sentToday, hour: hour)
    }

    func testOffByDefaultBlocksEverything() {
        XCTAssertFalse(NudgeGate.allows(input(enabled: false)))
    }

    func testQuietHoursWrapMidnight() {
        XCTAssertTrue(NudgeGate.inQuietHours(hour: 23, start: 23, end: 8))
        XCTAssertTrue(NudgeGate.inQuietHours(hour: 3, start: 23, end: 8))
        XCTAssertFalse(NudgeGate.inQuietHours(hour: 12, start: 23, end: 8))
        XCTAssertFalse(NudgeGate.inQuietHours(hour: 10, start: 10, end: 10),
                       "equal start/end = never quiet")
        XCTAssertFalse(NudgeGate.allows(input(hour: 23)))
    }

    func testDailyCapHolds() {
        XCTAssertTrue(NudgeGate.allows(input(maxPerDay: 3, sentToday: 2)))
        XCTAssertFalse(NudgeGate.allows(input(maxPerDay: 3, sentToday: 3)))
    }

    func testLateNightIsAbsoluteEvenOutsideQuietHours() {
        // quiet hours misconfigured to allow 2am — the late-night rule still blocks
        XCTAssertFalse(NudgeGate.allows(input(quietStart: 4, quietEnd: 5, hour: 2)))
    }

    func testDaytimeWithBudgetPasses() {
        XCTAssertTrue(NudgeGate.allows(input()))
    }
}
