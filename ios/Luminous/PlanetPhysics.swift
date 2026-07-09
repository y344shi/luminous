//
//  PlanetPhysics.swift
//  Luminous
//
//  The planetary-science computing module: the pure, Foundation-only math behind
//  the planetarium home. Kept framework-free (like the rest of the core) so it
//  builds into `LuminousCore` and is unit-tested by `swift test` on the Mac host.
//  `OrbitSim` (the CoreGraphics integrator) calls into these functions; none of
//  this touches SwiftUI, so the sim's *policy* stays deterministic and provable.
//
//  What lives here (all grounded in real orbital mechanics):
//   • importance → mass (bigger) and → orbital radius (closer): the recommender's
//     score decides how heavy and how central a wish's planet is.
//   • circular / escape speed and specific orbital energy (vis-viva), so a
//     "capture" spawn can be proven BOUND (energy < 0) by test, not by eyeball.
//   • a softened, hard-clamped pairwise attraction for same-category clustering
//     (a mini N-body term that can never overpower the central pull or eject).
//   • the kinematic local orbit of a moon around its live parent position.
//   • deterministic relatedness (shared category) for the shooting-star → moon
//     offer — no LLM.
//

import Foundation

enum PlanetPhysics {

    // MARK: - Small helpers

    static func clamp01(_ x: Double) -> Double { min(1, max(0, x)) }
    static func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, x)) }
    /// Hermite smoothstep — a gentle monotonic S-curve on [0,1], flat at both ends.
    static func smoothstep(_ x: Double) -> Double { let t = clamp01(x); return t * t * (3 - 2 * t) }

    // MARK: - Importance (recommendation score → [0,1])

    /// Normalize a raw recommendation score into [0,1] across the shown set.
    /// Degenerate spread (all equal) reads as the neutral middle.
    static func normalizedImportance(score: Double, min lo: Double, max hi: Double) -> Double {
        guard hi > lo else { return 0.5 }
        return clamp01((score - lo) / (hi - lo))
    }

    // MARK: - Importance → mass (bigger) & radius (closer)

    static let massMin = 0.6
    static let massMax = 1.8

    /// Importance → mass, smooth & strictly monotonic increasing on (0,1).
    /// Heavier planets render larger AND attract same-category neighbours harder.
    static func mass(importance i: Double) -> Double {
        massMin + (massMax - massMin) * smoothstep(clamp01(i))
    }

    /// Rendered planet diameter (points) from importance. Primaries read larger.
    /// Monotonic increasing — important, relevant wishes are big.
    static func diameter(importance i: Double, primary: Bool) -> Double {
        let base = primary ? 50.0 : 30.0
        let span = primary ? 26.0 : 16.0
        return base + span * smoothstep(clamp01(i))
    }

    /// How far importance pulls a planet inward, in points. Monotonic increasing
    /// in importance → the more important, the bigger the inward inset.
    static let maxInset = 44.0
    static func radiusInset(importance i: Double) -> Double {
        maxInset * smoothstep(clamp01(i))
    }

    /// A body's home orbital radius: its ring radius pulled inward by importance,
    /// floored so nothing crosses the photon ring / event horizon. Strictly
    /// DECREASING in importance for a fixed ring (above the floor) — important
    /// wishes sit closer to the centre glass; keeping the circular speed
    /// sqrt(mu/r) then makes them orbit faster, too.
    static func homeRadius(ringRadius: Double, importance i: Double, floor: Double) -> Double {
        max(floor, ringRadius - radiusInset(importance: i))
    }

    // MARK: - Kepler speeds & energy (vis-viva, softened-as-Kepler central field)

    static func circularSpeed(mu: Double, radius r: Double) -> Double { (mu / r).squareRoot() }
    static func escapeSpeed(mu: Double, radius r: Double) -> Double { (2 * mu / r).squareRoot() }

    /// Specific orbital energy ε = v²/2 − μ/r. ε < 0 ⇒ the orbit is BOUND.
    static func orbitalEnergy(speed v: Double, radius r: Double, mu: Double) -> Double {
        0.5 * v * v - mu / r
    }

    // MARK: - Capture (the flee-in)

    /// An off-schedule-but-important wish spawns far out and swings in. It gets a
    /// prograde (counter-clockwise, matching the disk) tangential velocity at
    /// `boundFraction` of escape speed, so — since boundFraction < 1 —
    /// ε = (f² − 1)·μ/r < 0: it is provably BOUND and cannot fly off. Below the
    /// circular fraction (1/√2 ≈ 0.707) it also falls inward, so it visibly
    /// arcs in from the edge before the ring-spring settles it.
    static func captureSpawn(angle a: Double, spawnRadius r: Double, mu: Double,
                             boundFraction f: Double = 0.55)
        -> (x: Double, y: Double, vx: Double, vy: Double) {
        let ff = clamp(f, 0.05, 0.95)                    // keep it strictly bound
        let v = ff * escapeSpeed(mu: mu, radius: r)
        return (cos(a) * r, sin(a) * r,                  // spawn on the far ring
                -sin(a) * v, cos(a) * v)                 // prograde tangent
    }

    // MARK: - Same-category attraction (mini N-body, softened + hard-clamped)

    /// Softened pairwise attraction acceleration on a body from a same-category
    /// partner at offset (dx,dy) = partner − self, scaled by the partner's mass.
    /// The magnitude is hard-capped at `maxAccel` (kept far below the central
    /// pull) so this can gently CLUSTER same-type wishes but never collapse them
    /// together or overpower the orbit. Points toward the partner.
    static func attraction(dx: Double, dy: Double, partnerMass m: Double,
                           strength g: Double, soft: Double, maxAccel: Double)
        -> (ax: Double, ay: Double) {
        let r2 = dx * dx + dy * dy + soft * soft
        let r = r2.squareRoot()
        let mag = min(g * m / r2, maxAccel)              // clamp the scalar
        return (mag * dx / r, mag * dy / r)              // and it decays with dx/r ≤ 1
    }

    // MARK: - Moons (kinematic local orbit around the live parent)

    /// A moon's local orbital angle at time t (true 3-body is unstable, so the
    /// moon is a kinematic satellite — it simply circles the parent's live
    /// position, co-planar with the disk).
    static func moonAngle(t: Double, period: Double, phase: Double) -> Double {
        phase + 2 * Double.pi * t / max(period, 0.001)
    }

    /// The moon's offset from its parent: a small ellipse, y squashed by the disk
    /// inclination so it lies in the same plane as everything else.
    static func moonOffset(radius r: Double, angle a: Double, ellipse: Double)
        -> (dx: Double, dy: Double) {
        (cos(a) * r, sin(a) * r * ellipse)
    }

    /// The moon's absolute position = parent + local offset.
    static func moonPosition(parentX px: Double, parentY py: Double,
                             radius r: Double, angle a: Double, ellipse: Double)
        -> (x: Double, y: Double) {
        let o = moonOffset(radius: r, angle: a, ellipse: ellipse)
        return (px + o.dx, py + o.dy)
    }

    // MARK: - Relatedness (deterministic — for the shooting-star → moon offer)

    /// The orbiting wish a fly-by suggestion could become a moon of: the first
    /// candidate that shares its category (and isn't the suggestion itself).
    /// Deterministic and framework-free — no model call.
    static func relatedParent(category: String,
                              excludingId: String? = nil,
                              candidates: [(id: String, category: String)]) -> String? {
        candidates.first { $0.category == category && $0.id != excludingId }?.id
    }
}
