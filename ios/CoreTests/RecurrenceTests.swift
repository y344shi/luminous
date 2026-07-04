//
//  RecurrenceTests.swift — pins the history-reads-back rules.
//

import XCTest
@testable import LuminousCore

final class RecurrenceTests: XCTestCase {

    private func daysAgo(_ d: Double) -> Date { Date().addingTimeInterval(-d * 86_400) }

    func testStatsFoldOutcomesAndPartialCounts() {
        let outcomes = [
            Outcome(time: daysAgo(12), seedId: "a", kind: .completed, semanticTime: .evening),
            Outcome(time: daysAgo(8), seedId: "a", kind: .partial, semanticTime: .evening),
            Outcome(time: daysAgo(4), seedId: "a", kind: .completed, semanticTime: .morning),
            Outcome(time: daysAgo(2), seedId: "a", kind: .skipped, semanticTime: .lunch),
        ]
        let s = Recurrence.stats(outcomes)["a"]!
        XCTAssertEqual(s.completions, 3, "partial always counts")
        XCTAssertEqual(s.medianGapDays ?? 0, 4, accuracy: 0.1)
        XCTAssertEqual(s.modalDoneTime, .evening)
        XCTAssertEqual(s.skipsByTime[.lunch], 1)
    }

    func testSleepingSeedResurfacesAtItsCadence() {
        var stats = Recurrence.SeedStats()
        stats.completions = 3
        stats.lastDone = daysAgo(6)
        stats.medianGapDays = 4
        let seed = makeSeed(status: .sleeping)
        var input = ContextInput(mood: .okay, energy: .medium)
        input.now = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!
        let ctx = ContextBuilder.build(input)
        let b = Recurrence.historyBonus(seed, ctx, stats: stats)
        XCTAssertGreaterThan(b, 0, "cadence passed → gently rises")
        XCTAssertLessThanOrEqual(b, 0.15, "always clamped")
    }

    func testRepeatedSkipsDampenTheContextNeverTheSeed() {
        var stats = Recurrence.SeedStats()
        stats.skipsByTime[.evening] = 3
        let seed = makeSeed()
        var input = ContextInput(mood: .okay, energy: .medium)
        input.now = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
        let evening = ContextBuilder.build(input)
        if evening.semanticTime == .evening {
            XCTAssertLessThan(Recurrence.historyBonus(seed, evening, stats: stats), 0)
        }
        // …but in another part of day the wish is untouched
        input.now = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        let morning = ContextBuilder.build(input)
        XCTAssertEqual(Recurrence.historyBonus(seed, morning, stats: stats), 0)
    }

    func testStableSerendipityHoldsStillWithinASlot() {
        let a = Scoring.stableSerendipity("seed_x", "evening")
        let b = Scoring.stableSerendipity("seed_x", "evening")
        XCTAssertEqual(a, b, "two opens a minute apart must agree")
        XCTAssertNotEqual(a, Scoring.stableSerendipity("seed_x", "morning"),
                          "…but a different part of day may differ")
        XCTAssertTrue((0..<1).contains(a))
    }
}

extension RecurrenceTests {
    func testJournalEngagementKeepsAPursuitWarmButClamped() {
        var stats = Recurrence.SeedStats()
        stats.engagedRecently = true
        var input = ContextInput(mood: .okay, energy: .medium)
        input.now = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!
        let ctx = ContextBuilder.build(input)
        let seed = makeSeed()
        XCTAssertEqual(Recurrence.historyBonus(seed, ctx, stats: stats), 0.05, accuracy: 0.001)
        // engagement + due-cadence together still clamp at 0.15
        stats.completions = 3
        stats.lastDone = Date().addingTimeInterval(-10 * 86_400)
        stats.medianGapDays = 2
        XCTAssertLessThanOrEqual(Recurrence.historyBonus(makeSeed(status: .sleeping), ctx, stats: stats), 0.15)
    }
}
