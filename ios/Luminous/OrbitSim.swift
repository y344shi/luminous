//
//  OrbitSim.swift
//  Luminous
//
//  A real gravity simulation for the planetarium home. Each wish is a body in a
//  Newtonian central field around the black hole; device-tilt is a uniform
//  perturbing field. Integrated with velocity-Verlet, so the orbits genuinely
//  precess and drift when you lean the phone — not a canned animation.
//
//  Physics notes (see ios/PLANETARIUM-PHYSICS.md):
//  • Central force  a = −μ · r̂ / r²  (softened near the hole so nothing blows up).
//    A circular orbit then has period T = 2π·r^{3/2} / √μ  → Kepler's 3rd law,
//    inner orbits faster, for free. μ is solved from a reference ring/period.
//  • Tilt is a small uniform acceleration (a fraction of the central pull at the
//    reference radius) so a lean shifts the orbit's focus and makes it precess
//    without ejecting the body.
//  • A plain (non-Observable) reference type held in @State: we mutate it every
//    frame from TimelineView and read it back the same frame. Because it isn't
//    observed, stepping it doesn't invalidate the view graph (no feedback loop).
//

import CoreGraphics
import Foundation

final class OrbitSim {
    struct Body {
        var x: Double, y: Double      // disk-plane position, relative to centre (points)
        var vx: Double, vy: Double    // disk-plane velocity (points/s)
        var ring: Int
        var importance: Double = 0.5  // ∈[0,1] — pulls the home radius inward
        var homeR: Double = OrbitSim.refRadius  // the ring radius, pulled in by importance
        // Moons: a body with a parentId is a kinematic satellite — it is NOT
        // integrated in the central field; each frame it is placed on a small
        // local orbit around its parent's live position.
        var parentId: String? = nil
        var moonR: Double = 0
        var moonPeriod: Double = 0
        var moonPhase: Double = 0
    }

    /// Nothing orbits closer than this — keeps important planets clear of the
    /// photon ring / event-horizon shadow at the centre.
    static let radiusFloor: Double = 88

    /// A body's home orbital radius: its ring radius pulled inward by importance
    /// (important wishes sit closer to the glass), floored. Keeping the circular
    /// speed sqrt(mu/homeR) then makes them orbit a touch faster, too.
    func homeRadius(ring: Int, importance i: Double) -> Double {
        PlanetPhysics.homeRadius(ringRadius: radius(for: ring), importance: i, floor: Self.radiusFloor)
    }

    private(set) var bodies: [String: Body] = [:]
    private var lastT: TimeInterval = 0

    // Central pull strength, solved so the reference ring keeps the old feel.
    let mu: Double
    /// Softening length: keeps a/r² finite if a perturbed orbit dives at the hole.
    let soft: Double = 30
    /// Disk inclination — the orbit plane is seen at ~35°, so y is compressed.
    let ellipse: CGFloat = 0.66

    /// Tilt acceleration, applied as a uniform field. Kept to ~40% of the central
    /// pull at the reference radius so it precesses rather than flings.
    private let tiltScale: Double

    /// Reference ring 0 radius and period — must match `radius(for:)` / the
    /// previous kinematic look so the switch is seamless.
    static let refRadius: Double = 136     // orbR(66) + 70
    static let refPeriod: Double = 70

    init() {
        let s = 2 * Double.pi * pow(Self.refRadius, 1.5) / Self.refPeriod
        mu = s * s
        // central accel at the reference radius = μ / r²
        let aRef = mu / (Self.refRadius * Self.refRadius)
        tiltScale = aRef * 0.4
    }

    func radius(for ring: Int) -> Double { Self.refRadius + Double(ring) * 50 }

    private func circularSpeed(_ r: Double) -> Double { (mu / r).squareRoot() }

    /// One body per placement. New ones launch on a circular orbit at their
    /// ring; vanished ones are dropped. Existing bodies keep their evolved
    /// state — and when a re-rank moves a wish to another ring, only its HOME
    /// ring changes: the spring walks it over smoothly (~12 s), it never jumps.
    func sync(_ places: [(id: String, ring: Int, idx: Int, count: Int,
                          importance: Double, capture: Bool)]) {
        let ids = Set(places.map { $0.id })
        // Keep moon bodies (managed by syncMoons); drop vanished planets.
        bodies = bodies.filter { $0.value.parentId != nil || ids.contains($0.key) }
        for pl in places {
            if var b = bodies[pl.id] {
                // A re-rank changes only the HOME radius; the ring-spring walks
                // the planet there smoothly (~12 s) — it never jumps. `capture`
                // only affects a body's FIRST spawn, never an existing one.
                var changed = false
                if b.ring != pl.ring { b.ring = pl.ring; changed = true }
                if abs(b.importance - pl.importance) > 0.001 { b.importance = pl.importance; changed = true }
                if changed {
                    b.homeR = homeRadius(ring: b.ring, importance: b.importance)
                    bodies[pl.id] = b
                }
                continue
            }
            let hr = homeRadius(ring: pl.ring, importance: pl.importance)
            let a = Double.pi / 2
                  + 2 * Double.pi / Double(max(pl.count, 1)) * Double(pl.idx)
                  + Double(pl.ring) * 0.6
            if pl.capture {
                // An important, off-schedule wish flees in from far out and is
                // gravitationally captured (sub-escape → bound); the ring-spring
                // then settles it onto its home orbit.
                let s = PlanetPhysics.captureSpawn(angle: a, spawnRadius: hr * 2.2, mu: mu)
                bodies[pl.id] = Body(x: s.x, y: s.y, vx: s.vx, vy: s.vy,
                                     ring: pl.ring, importance: pl.importance, homeR: hr)
            } else {
                let v = circularSpeed(hr)
                bodies[pl.id] = Body(
                    x: cos(a) * hr, y: sin(a) * hr,
                    vx: -sin(a) * v, vy: cos(a) * v,   // counter-clockwise tangent
                    ring: pl.ring, importance: pl.importance, homeR: hr)
            }
        }
    }

    /// Reconcile the set of moons: `moons` maps a moon's id to its parent id.
    /// New moons get a small deterministic local orbit; departed ones are
    /// dropped; a moon whose parent isn't currently a planet is dropped too.
    func syncMoons(_ moons: [(id: String, parentId: String)]) {
        let live = moons.filter { m in
            bodies[m.parentId]?.parentId == nil && bodies[m.parentId] != nil
        }
        let keep = Set(live.map { $0.id })
        for k in bodies.keys where bodies[k]?.parentId != nil && !keep.contains(k) {
            bodies[k] = nil
        }
        for m in live {
            if var b = bodies[m.id], b.parentId != nil {
                if b.parentId != m.parentId { b.parentId = m.parentId; bodies[m.id] = b }
                continue
            }
            var h: UInt64 = 5381
            for c in m.id.utf8 { h = h &* 33 &+ UInt64(c) }
            let phase = Double(h % 628) / 100.0            // 0..2π-ish
            bodies[m.id] = Body(x: 0, y: 0, vx: 0, vy: 0, ring: 0,
                                parentId: m.parentId,
                                moonR: 26, moonPeriod: 6, moonPhase: phase)
        }
    }

    /// Whether a body currently exists as an orbiting planet (not a moon).
    func isPlanet(_ id: String) -> Bool { bodies[id].map { $0.parentId == nil } ?? false }

    /// Weak radial spring toward each body's home ring: a perturbed orbit always
    /// finds its ring again (correction timescale ~12 s), so no phantom force or
    /// wild fling can permanently eject a wish. Small next to the central pull.
    private let springK: Double = 0.006

    /// Slow-adapting rest pose for the gravity vector. Tilt is measured against
    /// this baseline, so ANY static hold (upright, flat on a table, the zero
    /// vector in the Simulator) reads as "no lean" within seconds — only an
    /// active lean perturbs the orbits. This replaces the old hardcoded
    /// "+1 on y" upright assumption, which fabricated a constant downward force
    /// whenever the device wasn't vertical (the orbits-blown-away bug).
    private var baseline = CGSize.zero
    private var baselineSeeded = false

    private func accel(x: Double, y: Double, homeR: Double,
                       tx: Double, ty: Double) -> (Double, Double) {
        let r2 = x * x + y * y + soft * soft
        let r = r2.squareRoot()
        let invR3 = mu / (r2 * r)
        let spring = -springK * (r - homeR) / r
        return (-x * invR3 + spring * x + tx,
                -y * invR3 + spring * y + ty)
    }

    /// Advance every body to time `t`. `gravity` is the RAW CMDeviceMotion
    /// gravity vector (or .zero on the Simulator); the rest-pose baseline is
    /// handled here.
    func step(to t: TimeInterval, tilt gravity: CGSize, paused: Bool) {
        defer { lastT = t }
        if paused { return }
        guard lastT > 0 else { return }          // first frame: just seed lastT
        let dt = t - lastT
        if dt <= 0 || dt > 0.5 { return }        // ignore backsteps / resume gaps

        // Learn the rest pose (EMA, ~2 s time constant at 60 fps); the first
        // sample seeds it directly so launch never starts with a false lean.
        if baselineSeeded {
            baseline.width += (gravity.width - baseline.width) * 0.008
            baseline.height += (gravity.height - baseline.height) * 0.008
        } else {
            baseline = gravity
            baselineSeeded = true
        }
        let tx = Double(gravity.width - baseline.width) * tiltScale
        let ty = Double(gravity.height - baseline.height) * tiltScale

        let sub = 4
        let h = dt / Double(sub)
        for _ in 0..<sub {
            for k in bodies.keys where bodies[k]!.parentId == nil {   // planets only
                var b = bodies[k]!
                let (ax0, ay0) = accel(x: b.x, y: b.y, homeR: b.homeR, tx: tx, ty: ty)
                b.x += b.vx * h + 0.5 * ax0 * h * h
                b.y += b.vy * h + 0.5 * ay0 * h * h
                let (ax1, ay1) = accel(x: b.x, y: b.y, homeR: b.homeR, tx: tx, ty: ty)
                b.vx += 0.5 * (ax0 + ax1) * h
                b.vy += 0.5 * (ay0 + ay1) * h
                bodies[k] = b
            }
        }
        // Place moons on their local orbit around each parent's live position.
        // In disk-plane coords (ellipse: 1); screenPos applies the inclination.
        for k in bodies.keys where bodies[k]!.parentId != nil {
            var b = bodies[k]!
            guard let p = bodies[b.parentId!] else { continue }   // parent gone → hold
            let ang = PlanetPhysics.moonAngle(t: t, period: b.moonPeriod, phase: b.moonPhase)
            let off = PlanetPhysics.moonOffset(radius: b.moonR, angle: ang, ellipse: 1)
            b.x = p.x + off.dx
            b.y = p.y + off.dy
            bodies[k] = b
        }
    }

    /// Project a body to screen space (disk inclination applied to y).
    func screenPos(_ id: String, center: CGPoint) -> CGPoint? {
        guard let b = bodies[id] else { return nil }
        return CGPoint(x: center.x + CGFloat(b.x),
                       y: center.y + CGFloat(b.y) * ellipse)
    }
}
