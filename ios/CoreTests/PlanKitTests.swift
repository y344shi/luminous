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

final class WishTopicsTests: XCTestCase {
    func testCookingDetection() {
        XCTAssertTrue(WishTopics.isCooking("想给自己做顿好饭"))
        XCTAssertTrue(WishTopics.isCooking("学做菜"))
        XCTAssertTrue(WishTopics.isCooking("cook something nice"))
        XCTAssertFalse(WishTopics.isCooking("想学法语"))
        XCTAssertFalse(WishTopics.isCooking("出门走走"))
    }
}

final class TagSuggestTests: XCTestCase {

    func testCleanNormalizesAndRefuses() {
        XCTAssertEqual(TagSuggest.clean("  #法语 "), "法语")
        XCTAssertEqual(TagSuggest.clean("a-very-long-tag-name"), "a-very-lon", "capped at 10")
        XCTAssertNil(TagSuggest.clean("   "))
        XCTAssertNil(TagSuggest.clean("打卡"), "forbidden vocabulary never becomes a tag")
    }

    func testMergeDedupesAndCapsAtFive() {
        let merged = TagSuggest.merge(["法语", "法语", "阅读"],
                                      ["走动", "音乐", "休息", "下厨"])
        XCTAssertEqual(merged.count, 5)
        XCTAssertEqual(merged.first, "法语", "earlier lists win slots first")
        XCTAssertEqual(Set(merged).count, 5, "no duplicates")
    }

    func testSuggestOffersTopicsNeverTheFixedFacets() {
        let s = TagSuggest.suggest(title: "想学法语单词", categories: [.learning])
        XCTAssertTrue(s.contains("法语"))
        XCTAssertFalse(s.contains("学习"), "category chips stay fixed on the card, never as tags")
        let cook = TagSuggest.suggest(title: "做顿好饭", categories: [.body])
        XCTAssertTrue(cook.contains("下厨"))
        XCTAssertLessThanOrEqual(s.count, 6)
    }

    func testReservedFacetsCanNeverBecomeTags() {
        XCTAssertNil(TagSuggest.clean("探索"))
        XCTAssertNil(TagSuggest.clean("低能量"))
        XCTAssertNil(TagSuggest.clean("十几分钟"))
        XCTAssertNotNil(TagSuggest.clean("法语"))
    }
}

final class SeedTagsCodableTests: XCTestCase {

    func testTagsSurviveEncodeDecodeRoundTrip() throws {
        var draft = SeedParser.parse("想学法语单词")
        draft.tags = ["法语", "阅读"]
        let seed = SeedParser.draftToSeed(draft)
        XCTAssertEqual(seed.tags, ["法语", "阅读"])
        let data = try JSONEncoder().encode(seed)
        let back = try JSONDecoder().decode(Seed.self, from: data)
        XCTAssertEqual(back.tags, ["法语", "阅读"])
        XCTAssertEqual(back.title, seed.title)
    }

    func testLegacySeedWithoutTagsKeyStillDecodes() throws {
        // a pre-tags seed as persisted by older builds — no "tags" key at all
        let seed = SeedParser.draftToSeed(SeedParser.parse("出门走走"))
        var json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(seed)) as! [String: Any]
        json.removeValue(forKey: "tags")
        let legacy = try JSONSerialization.data(withJSONObject: json)
        let back = try JSONDecoder().decode(Seed.self, from: legacy)
        XCTAssertNil(back.tags)
        XCTAssertEqual(back.title, seed.title)
    }
}
