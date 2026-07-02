//
//  MentalityTests.swift — pins the soft-guess rules (a tilt, never a diagnosis).
//

import XCTest
@testable import LuminousCore

final class MentalityTests: XCTestCase {

    func testNeutralOrMissingEstimateContributesNothing() {
        let seed = makeSeed(categories: [.learning])
        XCTAssertEqual(Mentality.bonus(seed, estimate: nil), 0)
        XCTAssertEqual(Mentality.bonus(seed, estimate: MentalityEstimate()), 0,
                       "0.5 across the board = neutral = zero effect")
    }

    func testDepletionFavorsRestAndPenalizesDemand() {
        let worn = MentalityEstimate(restlessness: 0.5, depletion: 1.0, openness: 0.5)
        XCTAssertGreaterThan(Mentality.bonus(makeSeed(categories: [.recovery]), estimate: worn), 0)
        XCTAssertLessThan(Mentality.bonus(makeSeed(categories: [.learning]), estimate: worn), 0)
        XCTAssertLessThan(Mentality.bonus(makeSeed(categories: [.aesthetic], energy: .high),
                                          estimate: worn), 0)
    }

    func testRestlessnessFavorsMovementAndPenalizesLongFocus() {
        let fidgety = MentalityEstimate(restlessness: 1.0, depletion: 0.5, openness: 0.5)
        XCTAssertGreaterThan(Mentality.bonus(makeSeed(categories: [.body]), estimate: fidgety), 0)
        XCTAssertLessThan(Mentality.bonus(makeSeed(categories: [.aesthetic], duration: 45),
                                          estimate: fidgety), 0)
    }

    func testAlwaysClamped() {
        let extreme = MentalityEstimate(restlessness: 1, depletion: 1, openness: 1)
        for cats in [[SeedCategory.recovery], [.body], [.learning], [.exploration], [.creation]] {
            let b = Mentality.bonus(makeSeed(categories: cats, duration: 60, energy: .high),
                                    estimate: extreme)
            XCTAssertLessThanOrEqual(abs(b), 0.2)
        }
    }

    func testEstimateInitClampsInputs() {
        let e = MentalityEstimate(restlessness: 7, depletion: -3, openness: 0.4)
        XCTAssertEqual(e.restlessness, 1)
        XCTAssertEqual(e.depletion, 0)
        XCTAssertEqual(e.openness, 0.4)
    }
}
