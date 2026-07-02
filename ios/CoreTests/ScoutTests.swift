//
//  ScoutTests.swift — pins the proactive place-scout rules.
//

import XCTest
@testable import LuminousCore

final class ScoutTests: XCTestCase {

    private let library = OpportunityScout.Spot(name: "转角图书馆", kind: .library, distanceM: 200)
    private let park = OpportunityScout.Spot(name: "小公园", kind: .park, distanceM: 350)

    func testPairsWishWithFittingPlace() {
        let french = makeSeed(id: "fr", title: "记三个法语单词", categories: [.learning])
        let out = OpportunityScout.scout(seeds: [french], spots: [park, library],
                                         hour: 14, isLateNight: false)
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].seedId, "fr")
        XCTAssertTrue(out[0].place?.contains("图书馆") == true)
        XCTAssertTrue(out[0].place?.contains("200m") == true)
    }

    func testLateNightAndOffHoursScoutNothing() {
        let french = makeSeed(id: "fr", categories: [.learning])
        XCTAssertTrue(OpportunityScout.scout(seeds: [french], spots: [library],
                                             hour: 2, isLateNight: true).isEmpty)
        XCTAssertTrue(OpportunityScout.scout(seeds: [french], spots: [library],
                                             hour: 22, isLateNight: false).isEmpty,
                      "no scouting outside 8:00-20:00 either")
    }

    func testOnlyActiveSeedsAndCappedAtLimit() {
        let sleeping = makeSeed(id: "s", categories: [.learning], status: .sleeping)
        XCTAssertTrue(OpportunityScout.scout(seeds: [sleeping], spots: [library],
                                             hour: 14, isLateNight: false).isEmpty)

        let many = (0..<4).map { makeSeed(id: "m\($0)", categories: [.body]) }
        let gyms = (0..<4).map { OpportunityScout.Spot(name: "健身房\($0)", kind: .gym, distanceM: 100 + Double($0)) }
        let out = OpportunityScout.scout(seeds: many, spots: gyms, hour: 14, isLateNight: false)
        XCTAssertEqual(out.count, 2, "never more than a couple of scouted moments")
    }

    func testFarPlacesAreNotOffered() {
        let farLib = OpportunityScout.Spot(name: "远图书馆", kind: .library, distanceM: 1500)
        let french = makeSeed(id: "fr", categories: [.learning])
        XCTAssertTrue(OpportunityScout.scout(seeds: [french], spots: [farLib],
                                             hour: 14, isLateNight: false).isEmpty,
                      "beyond a short walk (800m) isn't 'right here'")
    }
}
