//
//  PlanKitTests.swift — pins the breakdown validation + language scenarios.
//

import XCTest
@testable import LuminousCore

final class PlanKitTests: XCTestCase {

    func testValidateEnforcesClosedSetCapsAndWords() {
        let valid = PlanKit.validate([
            ("找一个安静的角落", "route", "图书馆"),
            ("挑三个词", "vocab", "点餐"),
            ("完成任务并打卡", "vocab", ""),          // forbidden words → dropped
            ("发射到月球", "rocket", ""),             // unknown resource → dropped
            ("这一步的标题实在是太长了长到完全不像一个温柔的小步骤了吧", "none", ""), // >24 chars → dropped
        ])
        XCTAssertEqual(valid?.count, 2)
        XCTAssertEqual(valid?[0].resource, .route)
        XCTAssertEqual(valid?[1].resource, .vocab)
    }

    func testValidateNilWhenTooLittleSurvives() {
        XCTAssertNil(PlanKit.validate([("打卡", "none", "")]),
                     "fewer than 2 clean steps → use the fallback")
    }

    func testValidateCapsAtFourAndDedupes() {
        let raw = (0..<6).map { ("第\($0)小步", "none", "") } + [("第0小步", "none", "")]
        XCTAssertEqual(PlanKit.validate(raw)?.count, 4)
    }

    func testFallbackNeverEmptyAndMatchesNature() {
        let learn = PlanKit.fallback(for: makeSeed(title: "记三个法语单词", categories: [.learning]))
        XCTAssertFalse(learn.isEmpty)
        XCTAssertTrue(learn.contains { $0.resource == .vocab })
        XCTAssertTrue(learn.contains { $0.resource == .photo })

        let rest = PlanKit.fallback(for: makeSeed(categories: [.recovery]))
        XCTAssertTrue(rest.contains { $0.resource == .breath })

        let out = PlanKit.fallback(for: makeSeed(categories: [.exploration]))
        XCTAssertTrue(out.contains { $0.resource == .route })
    }

    func testLanguageScenariosGrowFromTheDay() {
        XCTAssertTrue(LanguageScenarios.options(nearby: [.restaurant], activity: .still, hour: 12)
            .contains("点餐与食物"))
        XCTAssertTrue(LanguageScenarios.options(nearby: [], activity: .transit, hour: 12)
            .contains("出行与问路"))
        XCTAssertTrue(LanguageScenarios.options(nearby: [.library], activity: .still, hour: 14)
            .contains("阅读与展览"))
        // never empty, never more than 3
        let all = LanguageScenarios.options(nearby: [.restaurant, .library], activity: .walking, hour: 20)
        XCTAssertFalse(all.isEmpty)
        XCTAssertLessThanOrEqual(all.count, 3)
        XCTAssertFalse(LanguageScenarios.options(nearby: [], activity: nil, hour: 3).isEmpty)
    }
}
