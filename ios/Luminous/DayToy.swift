//
//  DayToy.swift
//  Luminous — 今天的小机器: a little day-object assembled from today's wishes
//
//  Pure and Foundation-only (in the SwiftPM test package; NOT the watch target —
//  the toy is an iPhone/iPad/Mac surface). Each fulfilled wish grows ONE part,
//  by its category; how the wish felt shapes the part's size, glow, and motor.
//  Renderer-agnostic — SceneKit reads these values, but the model knows nothing
//  about rendering. See ios/BUILD-TODAY-PLAN.md.
//
//  Philosophy: a machine with one part is a WHOLE little thing. Never
//  "incomplete", never a count to grow. Extra completions past the calm cap
//  still count as wishes — the machine just doesn't clutter.
//

import Foundation

/// How a completed wish felt — the one rating that shapes its part.
enum PartFeel: String, Codable, CaseIterable {
    case tinyButReal      // 很小，但真的
    case feltGood         // 挺好的
    case changedMyDay     // 今天因此不一样了

    var label: String {
        switch self {
        case .tinyButReal:  return "很小，但真的"
        case .feltGood:     return "挺好的"
        case .changedMyDay: return "今天因此不一样了"
        }
    }

    /// 0…1 — drives part scale / glow / motor strength.
    var weight: Double {
        switch self {
        case .tinyButReal:  return 0.30
        case .feltGood:     return 0.62
        case .changedMyDay: return 1.0
        }
    }
}

enum PartMaterial: String, Codable { case wood, paper, glass, brass, cloth, light }

/// The physical part a wish grows into. A category offers a few; a wish always
/// grows the SAME one (stable hash of its id) so your machine never reshuffles.
enum PartKind: String, Codable, CaseIterable {
    case cushionWheel, stabilizer            // recovery
    case sail, springLeg, propeller          // body / exploration (walk)
    case engine, sparkCore                   // creation
    case passengerLight, lantern, antenna    // connection
    case compass, telescope, mapFin          // learning
    case prism, chime                        // aesthetic

    var material: PartMaterial {
        switch self {
        case .cushionWheel, .stabilizer, .sail, .chime: return .cloth
        case .springLeg, .propeller, .compass, .telescope, .mapFin: return .brass
        case .engine, .sparkCore: return .light
        case .passengerLight, .lantern, .prism: return .glass
        case .antenna: return .brass
        }
    }

    /// Parts that carry light through them.
    var glows: Bool {
        switch self {
        case .engine, .sparkCore, .passengerLight, .lantern, .prism: return true
        default: return false
        }
    }
}

enum DayToy {
    /// Which parts each wish category can grow.
    static func kinds(for category: SeedCategory) -> [PartKind] {
        switch category {
        case .recovery:               return [.cushionWheel, .stabilizer]
        case .body, .exploration:     return [.sail, .springLeg, .propeller]
        case .creation:               return [.engine, .sparkCore]
        case .connection:             return [.passengerLight, .lantern, .antenna]
        case .learning:               return [.compass, .telescope, .mapFin]
        case .aesthetic:              return [.prism, .chime]
        }
    }

    /// The stable pick for a wish — same wish, same part, forever.
    static func kind(category: SeedCategory, seedId: String) -> PartKind {
        let options = kinds(for: category)
        var h: UInt64 = 5381
        for b in seedId.utf8 { h = h &* 33 &+ UInt64(b) }
        return options[Int(h % UInt64(max(options.count, 1)))]
    }
}

/// One part on today's machine.
struct DayPart: Codable, Identifiable, Hashable {
    var id: String
    var seedId: String
    var seedTitle: String
    var category: SeedCategory
    var kind: PartKind
    var feel: PartFeel
    var bornAt: String

    init(seed: Seed, feel: PartFeel) {
        self.id = DomainUtil.uid("part")
        self.seedId = seed.id
        self.seedTitle = seed.title
        let cat = seed.categories.first ?? .recovery
        self.category = cat
        self.kind = DayToy.kind(category: cat, seedId: seed.id)
        self.feel = feel
        self.bornAt = DomainUtil.nowIso()
    }

    /// Rendering-facing derived values (0…):
    var scale: Double { 0.6 + 0.7 * feel.weight }               // 0.6 … 1.3
    var glow: Double  { kind.glows ? (0.3 + 0.7 * feel.weight) : 0 }
    var motor: Double { feel == .tinyButReal ? 0 : feel.weight } // no motor for the quietest
}

/// Today's little machine.
struct DayObject: Codable, Hashable {
    var dateKey: String
    var parts: [DayPart]
    var playedAt: String?
    /// When the day was kept into 痕迹 (the keepsake). nil until collected.
    var keptAt: String?
    /// A rendered PNG of the machine at the moment it was kept (base64 in JSON;
    /// optional — the keepsake still works if rendering isn't available).
    var snapshot: Data?

    init(dateKey: String = DomainUtil.localDateKey(),
         parts: [DayPart] = [], playedAt: String? = nil,
         keptAt: String? = nil, snapshot: Data? = nil) {
        self.dateKey = dateKey; self.parts = parts; self.playedAt = playedAt
        self.keptAt = keptAt; self.snapshot = snapshot
    }

    /// True once the day has been collected into 痕迹.
    var kept: Bool { keptAt != nil }

    /// A calm number of visible parts. Beyond it, the oldest quietly drop off
    /// the render — the wishes still counted, the machine just stays legible.
    static let maxParts = 8

    /// True only before the very first part — used to show the empty craft.
    var isEmpty: Bool { parts.isEmpty }

    /// Add a part for a completed wish. Re-completing the same wish replaces its
    /// part (never piles up); the visible set is capped.
    mutating func add(_ part: DayPart) {
        parts.removeAll { $0.seedId == part.seedId }
        parts.append(part)
        if parts.count > Self.maxParts {
            parts.removeFirst(parts.count - Self.maxParts)
        }
    }

    var played: Bool { playedAt != nil }
}
