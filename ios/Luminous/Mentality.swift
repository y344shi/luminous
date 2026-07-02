//
//  Mentality.swift
//  Luminous — a soft guess at how the day feels, never a diagnosis
//
//  Pure and Foundation-only (in the SwiftPM test package and the watch target).
//  The estimate itself may come from the on-device model (MentalityAI.swift) or
//  stay neutral; either way it is ONE clamped scoring term (±0.2) and is never
//  shown to the user as a label. It tilts which wishes fit the moment — it
//  never tells anyone what they are.
//

import Foundation

/// How the day seems to be sitting, each 0…1. Neutral = 0.5.
struct MentalityEstimate: Hashable {
    var restlessness: Double = 0.5   // fidgety, lots of transitions
    var depletion: Double = 0.5      // worn down, little left
    var openness: Double = 0.5       // room for something new
    init() {}
    init(restlessness: Double, depletion: Double, openness: Double) {
        self.restlessness = min(max(restlessness, 0), 1)
        self.depletion = min(max(depletion, 0), 1)
        self.openness = min(max(openness, 0), 1)
    }
}

enum Mentality {

    /// The single mentality term, clamped to ±0.2. Strong pulls only appear at
    /// the extremes; a neutral estimate contributes nothing.
    static func bonus(_ seed: Seed, estimate: MentalityEstimate?) -> Double {
        guard let e = estimate else { return 0 }
        let cats = Set(seed.categories)
        var b = 0.0

        // Worn down → rest and small bodily anchors fit; demanding work doesn't.
        let depletion = e.depletion - 0.5
        if depletion > 0 {
            if cats.contains(.recovery) || cats.contains(.body) { b += depletion * 0.3 }
            if cats.contains(.learning) || cats.contains(.creation) { b -= depletion * 0.2 }
            if seed.energyRequired == .high { b -= depletion * 0.3 }
        }
        // Fidgety → moving helps; long still focus doesn't.
        let restless = e.restlessness - 0.5
        if restless > 0 {
            if cats.contains(.body) || cats.contains(.exploration) { b += restless * 0.25 }
            if seed.estimatedDurationMin > 30 { b -= restless * 0.2 }
        }
        // Open → a good day to explore, make, reach out.
        let open = e.openness - 0.5
        if open > 0 {
            if cats.contains(.exploration) || cats.contains(.creation)
                || cats.contains(.connection) { b += open * 0.25 }
        }
        return DomainUtil.clamp(b, -0.2, 0.2)
    }
}
