//
//  DayToyTests.swift
//  Pins the pure day-object model: stable part kinds, felt→derived values, and
//  the assembly rules (dedup, cap, "one part is whole"). No rendering here.
//

import XCTest
@testable import LuminousCore

final class DayToyTests: XCTestCase {

    // A wish always grows the SAME part — stable hash of its id, never reshuffles.
    func testStablePartKind() {
        let seed = makeSeed(id: "seed_walk", categories: [.exploration])
        let a = DayPart(seed: seed, feel: .feltGood)
        let b = DayPart(seed: seed, feel: .changedMyDay)
        XCTAssertEqual(a.kind, b.kind, "same seed → same part kind")
        XCTAssertTrue(DayToy.kinds(for: .exploration).contains(a.kind))
    }

    // Felt rating shapes size / glow / motor; the quietest carries no motor.
    func testFeelDrivesDerivedValues() {
        let glowSeed = makeSeed(id: "s_create", categories: [.creation]) // engine/sparkCore → glows
        let quiet = DayPart(seed: glowSeed, feel: .tinyButReal)
        let loud  = DayPart(seed: glowSeed, feel: .changedMyDay)
        XCTAssertEqual(quiet.motor, 0, "tinyButReal is a quiet, motorless piece")
        XCTAssertGreaterThan(loud.motor, quiet.motor)
        XCTAssertGreaterThan(loud.scale, quiet.scale)
        XCTAssertGreaterThan(loud.glow, 0, "a light-carrying part glows")
    }

    // Re-completing a wish replaces its part (never piles up); cap stays calm.
    func testAddDedupsAndCaps() {
        var obj = DayObject(dateKey: "2026-07-08")
        XCTAssertTrue(obj.isEmpty)
        let seed = makeSeed(id: "s1", categories: [.recovery])
        obj.add(DayPart(seed: seed, feel: .tinyButReal))
        obj.add(DayPart(seed: seed, feel: .changedMyDay))   // same seed
        XCTAssertEqual(obj.parts.count, 1, "same wish → one part, replaced")
        XCTAssertEqual(obj.parts.first?.feel, .changedMyDay)
        XCTAssertFalse(obj.isEmpty)

        for i in 0..<12 {
            obj.add(DayPart(seed: makeSeed(id: "s_\(i)", categories: [.body]), feel: .feltGood))
        }
        XCTAssertLessThanOrEqual(obj.parts.count, DayObject.maxParts,
                                 "the visible set stays legible (capped)")
    }

    // Codable round-trip — the payload persistence relies on it.
    func testCodableRoundTrip() throws {
        var obj = DayObject(dateKey: "2026-07-08")
        obj.add(DayPart(seed: makeSeed(id: "sx", categories: [.connection]), feel: .feltGood))
        let data = try JSONEncoder().encode(obj)
        let back = try JSONDecoder().decode(DayObject.self, from: data)
        XCTAssertEqual(back, obj)
    }
}
