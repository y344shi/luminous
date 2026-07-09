//
//  OceanSimTests.swift — pins the ocean buoyancy invariants.
//

import XCTest
@testable import LuminousCore

final class OceanSimTests: XCTestCase {

    func testRadiusGrowsWithImportance() {
        XCTAssertLessThan(OceanSim.radius(importance: 0.2), OceanSim.radius(importance: 0.9))
    }

    func testImportantWishesFloatShallower() {
        let rBig = OceanSim.radius(importance: 0.9)
        let rSmall = OceanSim.radius(importance: 0.2)
        XCTAssertLessThan(OceanSim.restDepth(importance: 0.9, radius: rBig),
                          OceanSim.restDepth(importance: 0.2, radius: rSmall),
                          "more relevant → shallower rest depth (floats higher)")
    }

    func testSettlesNearRestHeight() {
        let sim = OceanSim()
        sim.sync([("a", 0.6)], waterTop: 200, width: 400, height: 800)
        let rest = sim.bodies["a"]!.restY
        var t = 0.0
        for _ in 0..<180 { t += 1.0 / 60; sim.advance(dt: 1.0 / 60, t: t, tiltX: 0, tiltY: 0) }
        XCTAssertLessThan(abs(sim.bodies["a"]!.y - rest), 14, "settles near its float height (± bob)")
    }

    func testStaysInBounds() {
        let sim = OceanSim()
        // a deep (low-importance) wish in a short container must clamp into view
        sim.sync([("a", 0.0)], waterTop: 100, width: 300, height: 360)
        var t = 0.0
        for _ in 0..<120 { t += 1.0 / 60; sim.advance(dt: 1.0 / 60, t: t, tiltX: 0.4, tiltY: 0) }
        let b = sim.bodies["a"]!
        XCTAssertGreaterThanOrEqual(b.x, b.radius - 0.01)
        XCTAssertLessThanOrEqual(b.x, 300 - b.radius + 0.01)
        XCTAssertLessThanOrEqual(b.y, 360 - sim.bottomInset - b.radius + 0.01)
    }

    func testSeparationPushesOverlappingBubblesApart() {
        let sim = OceanSim()
        sim.sync([("a", 1.0), ("b", 1.0)], waterTop: 100, width: 200, height: 800)
        let a0 = sim.bodies["a"]!, b0 = sim.bodies["b"]!
        let d0 = hypot(b0.x - a0.x, b0.y - a0.y)
        var t = 0.0
        for _ in 0..<60 { t += 1.0 / 60; sim.advance(dt: 1.0 / 60, t: t, tiltX: 0, tiltY: 0) }
        let a1 = sim.bodies["a"]!, b1 = sim.bodies["b"]!
        let d1 = hypot(b1.x - a1.x, b1.y - a1.y)
        XCTAssertGreaterThan(d1, d0, "overlapping bubbles drift apart")
    }
}
