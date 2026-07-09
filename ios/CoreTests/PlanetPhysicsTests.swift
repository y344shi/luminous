//
//  PlanetPhysicsTests.swift
//  The pure math behind the planetarium's planetary-science module. These pin
//  the physical invariants the beloved home relies on: important wishes are big
//  and near the middle; a captured wish is provably bound; same-type attraction
//  can never eject; a moon sits exactly on its parent + a bounded local orbit.
//

import XCTest
@testable import LuminousCore

final class PlanetPhysicsTests: XCTestCase {

    // A μ in the same ballpark as the shipped sim (refRadius 136, refPeriod 70).
    private var mu: Double {
        let s = 2 * Double.pi * pow(136.0, 1.5) / 70.0
        return s * s
    }

    // MARK: importance → mass & radius

    func testImportanceHigherMeansHeavier() {
        // Strictly monotonic increasing across the range.
        let samples = stride(from: 0.0, through: 1.0, by: 0.1).map { PlanetPhysics.mass(importance: $0) }
        for i in 1..<samples.count { XCTAssertGreaterThan(samples[i], samples[i - 1]) }
        XCTAssertEqual(samples.first!, PlanetPhysics.massMin, accuracy: 1e-9)
        XCTAssertEqual(samples.last!,  PlanetPhysics.massMax, accuracy: 1e-9)
    }

    func testImportanceHigherMeansBiggerDiameter() {
        XCTAssertGreaterThan(PlanetPhysics.diameter(importance: 0.9, primary: true),
                             PlanetPhysics.diameter(importance: 0.1, primary: true))
        // Primaries read larger than ambient at equal importance.
        XCTAssertGreaterThan(PlanetPhysics.diameter(importance: 0.5, primary: true),
                             PlanetPhysics.diameter(importance: 0.5, primary: false))
    }

    func testImportanceHigherMeansSmallerRadius() {
        let ring = 136.0
        let near = PlanetPhysics.homeRadius(ringRadius: ring, importance: 0.9, floor: 60)
        let far  = PlanetPhysics.homeRadius(ringRadius: ring, importance: 0.1, floor: 60)
        XCTAssertLessThan(near, far)                       // important → closer
        // Monotonic decreasing over the whole range, and always above the floor.
        var prev = Double.infinity
        for i in stride(from: 0.0, through: 1.0, by: 0.1) {
            let r = PlanetPhysics.homeRadius(ringRadius: ring, importance: i, floor: 60)
            XCTAssertLessThanOrEqual(r, prev)
            XCTAssertGreaterThanOrEqual(r, 60)
            prev = r
        }
    }

    func testInnerStaysFasterAfterImportanceInset() {
        // Keeping circular speed sqrt(mu/r): a smaller (more important) radius is
        // faster — the "inner = faster" law survives the importance mapping.
        let ring = 186.0
        let rNear = PlanetPhysics.homeRadius(ringRadius: ring, importance: 0.95, floor: 60)
        let rFar  = PlanetPhysics.homeRadius(ringRadius: ring, importance: 0.05, floor: 60)
        XCTAssertGreaterThan(PlanetPhysics.circularSpeed(mu: mu, radius: rNear),
                             PlanetPhysics.circularSpeed(mu: mu, radius: rFar))
    }

    func testNormalizedImportanceEdges() {
        XCTAssertEqual(PlanetPhysics.normalizedImportance(score: 0.5, min: 0.5, max: 0.5), 0.5)
        XCTAssertEqual(PlanetPhysics.normalizedImportance(score: 0.2, min: 0.2, max: 1.2), 0.0, accuracy: 1e-9)
        XCTAssertEqual(PlanetPhysics.normalizedImportance(score: 1.2, min: 0.2, max: 1.2), 1.0, accuracy: 1e-9)
        XCTAssertEqual(PlanetPhysics.normalizedImportance(score: 5,   min: 0.2, max: 1.2), 1.0) // clamped
    }

    // MARK: capture — provably bound

    func testCaptureSpawnIsBound() {
        for r in [200.0, 320.0, 480.0] {
            let s = PlanetPhysics.captureSpawn(angle: 0.9, spawnRadius: r, mu: mu, boundFraction: 0.55)
            let speed = (s.vx * s.vx + s.vy * s.vy).squareRoot()
            let energy = PlanetPhysics.orbitalEnergy(speed: speed, radius: r, mu: mu)
            XCTAssertLessThan(energy, 0, "capture spawn at r=\(r) must be bound (ε<0)")
            // spawned exactly on the far ring
            XCTAssertEqual((s.x * s.x + s.y * s.y).squareRoot(), r, accuracy: 1e-6)
        }
    }

    func testCaptureFallsInward() {
        // Below circular speed ⇒ it starts inside apoapsis and falls toward centre:
        // the radial velocity component is ~0 (pure tangent) but speed < circular.
        let r = 320.0
        let s = PlanetPhysics.captureSpawn(angle: 0.0, spawnRadius: r, mu: mu, boundFraction: 0.55)
        let speed = (s.vx * s.vx + s.vy * s.vy).squareRoot()
        XCTAssertLessThan(speed, PlanetPhysics.circularSpeed(mu: mu, radius: r))
        XCTAssertLessThan(speed, PlanetPhysics.escapeSpeed(mu: mu, radius: r))
    }

    func testCaptureFractionClampedStaysBound() {
        // Even asking for an unbound fraction, the clamp keeps it bound.
        let r = 300.0
        let s = PlanetPhysics.captureSpawn(angle: 0.3, spawnRadius: r, mu: mu, boundFraction: 3.0)
        let speed = (s.vx * s.vx + s.vy * s.vy).squareRoot()
        XCTAssertLessThan(PlanetPhysics.orbitalEnergy(speed: speed, radius: r, mu: mu), 0)
    }

    // MARK: same-category attraction — clamped, directional, weak

    func testAttractionIsClampedAndDirectional() {
        let maxA = 0.12
        // Very close ⇒ would blow up without the clamp; must stay ≤ maxAccel.
        for d in [1.0, 5.0, 30.0, 120.0, 400.0] {
            let a = PlanetPhysics.attraction(dx: d, dy: 0, partnerMass: PlanetPhysics.massMax,
                                             strength: 300, soft: 40, maxAccel: maxA)
            let mag = (a.ax * a.ax + a.ay * a.ay).squareRoot()
            XCTAssertLessThanOrEqual(mag, maxA + 1e-9, "attraction must never exceed the cap")
            XCTAssertGreaterThan(a.ax, 0, "must point toward the partner (+dx)")
        }
    }

    func testAttractionStaysBelowCentralPull() {
        // The cap must be well under the central acceleration at the reference
        // radius, or clustering could unbind an orbit.
        let centralAtRef = mu / (136.0 * 136.0)
        XCTAssertLessThan(0.12, centralAtRef * 0.3)
    }

    func testAttractionDecaysWithDistance() {
        let near = PlanetPhysics.attraction(dx: 150, dy: 0, partnerMass: 1, strength: 300, soft: 40, maxAccel: 0.12)
        let far  = PlanetPhysics.attraction(dx: 400, dy: 0, partnerMass: 1, strength: 300, soft: 40, maxAccel: 0.12)
        XCTAssertGreaterThan(near.ax, far.ax)
    }

    // MARK: moons — position = parent + bounded local orbit

    func testMoonPositionIsParentPlusBoundedOffset() {
        let px = 120.0, py = -40.0, lr = 30.0, ell = 0.66
        for a in stride(from: 0.0, to: 2 * Double.pi, by: 0.4) {
            let p = PlanetPhysics.moonPosition(parentX: px, parentY: py, radius: lr, angle: a, ellipse: ell)
            let off = (pow(p.x - px, 2) + pow(p.y - py, 2)).squareRoot()
            XCTAssertLessThanOrEqual(off, lr + 1e-9)        // ellipse squashes y ⇒ ≤ radius
            XCTAssertGreaterThan(off, 0)                    // never on top of the parent
        }
    }

    func testMoonAngleAdvancesWithTime() {
        let a0 = PlanetPhysics.moonAngle(t: 0,  period: 14, phase: 0.5)
        let a1 = PlanetPhysics.moonAngle(t: 7,  period: 14, phase: 0.5)
        XCTAssertEqual(a0, 0.5, accuracy: 1e-9)
        XCTAssertEqual(a1 - a0, Double.pi, accuracy: 1e-9) // half a period ⇒ π
    }

    // MARK: relatedness

    func testRelatedParentSharesCategory() {
        let cands = [(id: "a", category: "learning"),
                     (id: "b", category: "body"),
                     (id: "c", category: "learning")]
        XCTAssertEqual(PlanetPhysics.relatedParent(category: "learning", candidates: cands), "a")
        XCTAssertEqual(PlanetPhysics.relatedParent(category: "learning", excludingId: "a", candidates: cands), "c")
        XCTAssertNil(PlanetPhysics.relatedParent(category: "aesthetic", candidates: cands))
    }
}
