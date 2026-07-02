//
//  CoreTests.swift
//  The overnight green gate: pins the product-safety rules and the pure core.
//

import XCTest
@testable import LuminousCore

// MARK: - Helpers

func makeSeed(
    id: String = "seed_t",
    title: String = "测试愿望",
    categories: [SeedCategory] = [.recovery],
    minimumAction: String = "做一点点",
    duration: Int = 10,
    energy: Energy = .low,
    location: LocationType = .anywhere,
    times: [SemanticTime] = [],
    triggers: [String] = [],
    status: SeedStatus = .active
) -> Seed {
    Seed(id: id, rawText: title, title: title, description: nil,
         categories: categories, minimumAction: minimumAction,
         estimatedDurationMin: duration, energyRequired: energy,
         locationType: location, preferredTimes: times,
         triggerConditions: triggers, status: status,
         createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z")
}

func lateNightContext() -> ContextSnapshot {
    var input = ContextInput(mood: .tired, energy: .low)
    input.now = Calendar.current.date(bySettingHour: 2, minute: 0, second: 0, of: Date())!
    return ContextBuilder.build(input)
}

// MARK: - Late-night hard gate (the rule that must NEVER break)

final class LateNightGateTests: XCTestCase {

    func testLateNightNeverRecommendsOutdoorHighEnergyOrLong() {
        let unsafe = [
            makeSeed(id: "out", categories: [.exploration], location: .outdoor),
            makeSeed(id: "hi", categories: [.body], energy: .high),
            makeSeed(id: "long", categories: [.creation], duration: 45),
            makeSeed(id: "dt", categories: [.connection], location: .downtown),
        ]
        let rescue = makeSeed(id: "rescue", categories: [.recovery], duration: 5,
                              triggers: ["late_night"])
        let ctx = lateNightContext()
        XCTAssertTrue(ctx.isLateNight, "2am must classify as late night")

        let ranked = Scoring.rankSeeds(unsafe + [rescue], ctx, rng: { 0.5 })
        XCTAssertEqual(ranked.map(\.seed.id), ["rescue"],
                       "late night must surface only the safe rescue seed")
    }

    func testIsUnsafeLateNightRules() {
        XCTAssertTrue(Scoring.isUnsafeLateNight(makeSeed(location: .outdoor)))
        XCTAssertTrue(Scoring.isUnsafeLateNight(makeSeed(categories: [.exploration])))
        XCTAssertTrue(Scoring.isUnsafeLateNight(makeSeed(energy: .high)))
        XCTAssertTrue(Scoring.isUnsafeLateNight(makeSeed(duration: 21)))
        XCTAssertFalse(Scoring.isUnsafeLateNight(makeSeed(duration: 5)))
        // rescue markers override every unsafety rule
        XCTAssertFalse(Scoring.isUnsafeLateNight(
            makeSeed(location: .outdoor, triggers: ["rescue_mode"])))
    }

    func testPlaceBonusGatedOffLateNight() {
        var ctx = lateNightContext()
        ctx.nearbyKinds = [.library, .cafe]
        let learning = makeSeed(categories: [.learning])
        XCTAssertEqual(Scoring.placeBonus(learning, ctx), 0,
                       "never pull someone out at 2am, even to a library")
    }
}

// MARK: - Scoring shape

final class ScoringTests: XCTestCase {

    func testSensorBonusClamped() {
        var input = ContextInput(mood: .okay, energy: .medium)
        input.activity = .still; input.ambient = .quiet; input.arousal = .calm
        let ctx = ContextBuilder.build(input)
        let focus = makeSeed(categories: [.learning, .creation])
        let b = Scoring.sensorBonus(focus, ctx)
        XCTAssertLessThanOrEqual(abs(b), 0.25)
        XCTAssertGreaterThan(b, 0, "quiet+still+calm should favor focus work")
    }

    func testPlaceBonusMatchesAffinity() {
        var input = ContextInput(mood: .okay, energy: .medium)
        input.nearbyKinds = [.library]
        var ctx = ContextBuilder.build(input)
        // force a daytime context regardless of when tests run
        if ctx.isLateNight {
            input.now = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!
            ctx = ContextBuilder.build(input)
        }
        XCTAssertEqual(Scoring.placeBonus(makeSeed(categories: [.learning]), ctx), 0.12)
        XCTAssertEqual(Scoring.placeBonus(makeSeed(categories: [.body]), ctx), 0)
    }

    func testRankingIsDeterministicWithInjectedRng() {
        let seeds = (0..<5).map { makeSeed(id: "s\($0)", title: "愿望\($0)") }
        var input = ContextInput(mood: .okay, energy: .medium)
        input.now = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!
        let ctx = ContextBuilder.build(input)
        let a = Scoring.rankSeeds(seeds, ctx, rng: { 0.42 }).map(\.seed.id)
        let b = Scoring.rankSeeds(seeds, ctx, rng: { 0.42 }).map(\.seed.id)
        XCTAssertEqual(a, b)
    }
}

// MARK: - Sensor classifiers (thresholds pinned)

final class SensorClassifierTests: XCTestCase {

    func testClassifyActivity() {
        XCTAssertNil(Sensors.classifyActivity([1, 2, 3]), "needs ≥4 samples")
        XCTAssertEqual(Sensors.classifyActivity([9.8, 9.81, 9.79, 9.8]), .still)
        XCTAssertEqual(Sensors.classifyActivity([8, 11, 9, 12, 8.5, 11.5]), .walking)
        XCTAssertEqual(Sensors.classifyActivity([2, 18, 3, 19, 2.5, 17]), .transit)
    }

    func testClassifyAmbientAndArousal() {
        XCTAssertEqual(Sensors.classifyAmbient(0.02), .quiet)
        XCTAssertEqual(Sensors.classifyAmbient(0.08), .lively)
        XCTAssertEqual(Sensors.classifyArousal(80), .calm)
        XCTAssertEqual(Sensors.classifyArousal(88), .elevated)
        XCTAssertEqual(Sensors.classifyArousal(90, resting: 80), .calm)
    }

    func testWeatherClassification() {
        XCTAssertEqual(Weather.classify(code: 0), .clear)
        XCTAssertEqual(Weather.classify(code: 3), .clouds)
        XCTAssertEqual(Weather.classify(code: 61), .rain)
        XCTAssertEqual(Weather.classify(code: 75), .snow)
        XCTAssertEqual(Weather.classify(code: 45), .fog)
        XCTAssertTrue(Weather.isGoodOutdoor(kind: .clear, tempC: 20))
        XCTAssertFalse(Weather.isGoodOutdoor(kind: .rain, tempC: 20))
        XCTAssertFalse(Weather.isGoodOutdoor(kind: .clear, tempC: 2))
    }
}

// MARK: - Seed parser (keyword fallback must stay stable — it backs the LLM parser)

final class SeedParserTests: XCTestCase {

    func testFrenchWishParses() {
        let d = SeedParser.parse("想学法语单词")
        XCTAssertTrue(d.categories.contains(.learning))
        XCTAssertFalse(d.minimumAction.isEmpty)
    }

    func testUnknownTextFallsBackGently() {
        let d = SeedParser.parse("qwertyuiop")
        XCTAssertEqual(d.categories, [.recovery], "unknown wishes fall back to recovery")
        XCTAssertFalse(d.minimumAction.isEmpty, "never produce an empty minimum action")
    }

    func testDraftToSeedMintsActiveSeed() {
        let seed = SeedParser.draftToSeed(SeedParser.parse("想学法语"))
        XCTAssertEqual(seed.status, .active)
        XCTAssertFalse(seed.id.isEmpty)
    }

    func testTitleStripsWishPrefix() {
        let d = SeedParser.parse("我想给妈妈打个电话")
        XCTAssertFalse(d.title.hasPrefix("我想"))
    }
}

// MARK: - Traces (partial always counts; skips never disappear)

final class TraceTests: XCTestCase {

    func testPartialProducesAWarmTrace() {
        let t = TraceGenerator.buildTrace(makeSeed(), .partial, opportunityId: nil)
        XCTAssertFalse(t.text.isEmpty)
        XCTAssertEqual(t.partial, true)
    }

    func testSkippedStillLeavesATrace() {
        let t = TraceGenerator.buildTrace(makeSeed(), .skipped, opportunityId: nil)
        XCTAssertFalse(t.text.isEmpty, "skipping must never erase the day")
    }
}

// MARK: - Forbidden words (the vocabulary we refuse)

final class ForbiddenWordsTests: XCTestCase {

    func testTodoLanguageIsRefused() {
        XCTAssertFalse(ForbiddenWords.passes("完成任务，打卡今天"))
        XCTAssertFalse(ForbiddenWords.passes("This is OVERDUE"))
        XCTAssertFalse(ForbiddenWords.passes("高优先级：学法语"))
        XCTAssertFalse(ForbiddenWords.passes("你失败了"))
    }

    func testGentleLanguagePasses() {
        XCTAssertTrue(ForbiddenWords.passes("现在好像刚好适合做一点点"))
        XCTAssertTrue(ForbiddenWords.passes("倒一杯温水，慢慢喝完"))
    }
}
