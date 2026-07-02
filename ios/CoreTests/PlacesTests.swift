//
//  PlacesTests.swift — pins the home/work learning rules.
//

import XCTest
@testable import LuminousCore

final class PlacesTests: XCTestCase {

    private let cal = Calendar.current

    /// A date at hour `h` on a day offset from a fixed Monday.
    private func at(_ h: Int, dayOffset: Int = 0) -> Date {
        // find a recent Monday for weekday-stable tests
        var d = cal.startOfDay(for: Date())
        while cal.component(.weekday, from: d) != 2 { d = d.addingTimeInterval(-86_400) }
        return cal.date(byAdding: .day, value: dayOffset,
                        to: cal.date(bySettingHour: h, minute: 0, second: 0, of: d)!)!
    }

    func testCellKeyIsStableAndCoarse() {
        let a = Places.cellKey(lat: 31.23012, lon: 121.47401)
        let b = Places.cellKey(lat: 31.23019, lon: 121.47408)   // ~10 m away
        XCTAssertEqual(a, b, "nearby fixes share a coarse cell")
        let far = Places.cellKey(lat: 31.2340, lon: 121.4740)   // ~430 m away
        XCTAssertNotEqual(a, far)
    }

    func testHomeIsModalNightCellWithThreshold() {
        var obs: [Places.Observation] = []
        for d in 0..<5 { obs.append(.init(time: at(23, dayOffset: d), cell: "HOME")) }
        obs.append(.init(time: at(23, dayOffset: 5), cell: "BAR"))     // one night out
        XCTAssertEqual(Places.inferHome(obs), "HOME")

        // under the threshold → no guess (better silent than wrong)
        let sparse = (0..<3).map { Places.Observation(time: at(23, dayOffset: $0), cell: "H") }
        XCTAssertNil(Places.inferHome(sparse))
    }

    func testWorkIsWeekdayDaytimeAndNeverHome() {
        var obs: [Places.Observation] = []
        for d in 0..<5 { obs.append(.init(time: at(11, dayOffset: d), cell: "OFFICE")) }
        XCTAssertEqual(Places.inferWork(obs, home: "HOME"), "OFFICE")
        // working from home → no separate "work"
        XCTAssertNil(Places.inferWork(obs, home: "OFFICE"))
        // weekend daytime must not count toward work
        let weekend = (0..<5).map {
            Places.Observation(time: at(11, dayOffset: 5 + 7 * $0), cell: "CAFE") // Saturdays
        }
        XCTAssertNil(Places.inferWork(weekend, home: nil))
    }

    func testHintMapping() {
        XCTAssertEqual(Places.hint(currentCell: "H", home: "H", work: "W", activity: .still), .home)
        XCTAssertEqual(Places.hint(currentCell: "W", home: "H", work: "W", activity: .still), .work)
        XCTAssertEqual(Places.hint(currentCell: "X", home: "H", work: "W", activity: .still), .outdoor)
        XCTAssertEqual(Places.hint(currentCell: nil, home: "H", work: "W", activity: .still), .unknown)
        XCTAssertEqual(Places.hint(currentCell: "H", home: "H", work: nil, activity: .transit), .transit,
                       "transit motion wins over cell match")
    }
}
