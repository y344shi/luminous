//
//  RhythmTests.swift — pins the dwell/histogram math.
//

import XCTest
@testable import LuminousCore

final class RhythmTests: XCTestCase {

    private let cal = Calendar.current

    private func date(_ h: Int, _ m: Int = 0) -> Date {
        cal.date(bySettingHour: h, minute: m, second: 0, of: Date())!
    }

    func testSegmentsFoldTransitionsAndCapGaps() {
        let samples = [
            SenseSample(time: date(9, 0), state: "still"),
            SenseSample(time: date(9, 30), state: "walking"),
            SenseSample(time: date(9, 45), state: "still"),
        ]
        let segs = Rhythm.segments(samples, now: date(10, 0))
        XCTAssertEqual(segs.count, 3)
        XCTAssertEqual(segs[0].minutes, 30, accuracy: 0.01)
        XCTAssertEqual(segs[1].minutes, 15, accuracy: 0.01)
        XCTAssertEqual(segs[2].minutes, 15, accuracy: 0.01)

        // an 8-hour silent gap must be capped, not counted as one huge dwell
        let sparse = [SenseSample(time: date(1, 0), state: "still")]
        let capped = Rhythm.segments(sparse, now: date(9, 0))
        XCTAssertEqual(capped[0].minutes, 120, accuracy: 0.01)
    }

    func testMinutesByStateClipsToRange() {
        let samples = [SenseSample(time: date(9, 0), state: "still")]
        let segs = Rhythm.segments(samples, now: date(10, 0))
        let mins = Rhythm.minutesByState(segs, from: date(9, 30), to: date(10, 0))
        XCTAssertEqual(mins["still"] ?? 0, 30, accuracy: 0.01)
    }

    func testHourOfWeekSplitsAcrossHourBoundary() {
        let samples = [SenseSample(time: date(9, 45), state: "walking")]
        let segs = Rhythm.segments(samples, now: date(10, 15))
        let hist = Rhythm.hourOfWeek(segs)
        let bins = hist["walking"]!
        let b9 = Rhythm.binIndex(date(9, 45))
        let b10 = Rhythm.binIndex(date(10, 0))
        XCTAssertEqual(bins[b9], 15, accuracy: 0.01)
        XCTAssertEqual(bins[b10], 15, accuracy: 0.01)
        XCTAssertEqual(bins.reduce(0, +), 30, accuracy: 0.01)
    }

    func testTodayLineIsSoftAndOptional() {
        XCTAssertNil(Rhythm.todayLine([], now: date(12, 0)), "no data → say nothing")
        let samples = [SenseSample(time: date(9, 0), state: "still")]
        let line = Rhythm.todayLine(samples, now: date(12, 0))
        XCTAssertNotNil(line)
        XCTAssertTrue(line!.contains("安坐"))
        XCTAssertFalse(line!.contains("%"), "never a percentage/scoreboard")
    }
}
