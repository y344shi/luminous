//
//  OceanSim.swift
//  Luminous — the ocean skin's liquid: wishes float in water and slosh with tilt
//
//  Pure and Foundation-only (in the SwiftPM test package). A small 2D buoyancy
//  field: each wish is a bubble whose SIZE grows with relevance and which floats
//  toward a rest depth set by that relevance — more relevant = bigger = floats
//  higher toward the surface; minor wishes rest deeper but stay in view. The
//  device tilt (gyro) sloshes them sideways; a gentle bob keeps the water alive;
//  pairwise separation keeps bubbles from overlapping; everything is clamped to
//  the visible water. Coordinates are plain Doubles (y increases downward) so
//  the math stays testable; the view bridges to CGPoint.
//

import Foundation

final class OceanSim {

    struct Body {
        var x: Double, y: Double
        var vx: Double, vy: Double
        var radius: Double
        var restY: Double      // equilibrium float height (before bob)
        var phase: Double      // bob phase
    }

    private(set) var bodies: [String: Body] = [:]
    private var lastT: TimeInterval = 0

    var waterTop: Double = 0
    var width: Double = 0
    var height: Double = 0
    /// Space kept clear at the bottom (for the tab bar / add buttons).
    var bottomInset: Double = 150

    // Tuning
    private let kBuoy = 9.0          // spring toward the float depth
    private let damp = 2.6           // velocity damping
    private let tiltScale = 260.0    // how hard a lean sloshes
    private let bobAmp = 6.0
    private let bobFreq = 1.2

    /// Bubble radius from importance ∈[0,1] — relevance is volume.
    static func radius(importance i: Double) -> Double {
        22 + 26 * min(1, max(0, i))
    }

    /// Rest DEPTH below the surface — important wishes (i→1) float shallow (near
    /// the top); minor wishes (i→0) rest deeper. Monotonic decreasing in i.
    static func restDepth(importance i: Double, radius r: Double) -> Double {
        r + (1 - min(1, max(0, i))) * 220
    }

    func sync(_ specs: [(id: String, importance: Double)],
              waterTop: Double, width: Double, height: Double) {
        self.waterTop = waterTop; self.width = width; self.height = height
        let ids = Set(specs.map { $0.id })
        bodies = bodies.filter { ids.contains($0.key) }
        for (i, s) in specs.enumerated() {
            let r = Self.radius(importance: s.importance)
            let restY = waterTop + Self.restDepth(importance: s.importance, radius: r)
            if var b = bodies[s.id] {
                b.radius = r; b.restY = restY; bodies[s.id] = b
            } else {
                var h: UInt64 = 5381
                for c in s.id.utf8 { h = h &* 33 &+ UInt64(c) }
                let x = width * (0.16 + 0.68 * Double(i % 5) / 4.0)
                bodies[s.id] = Body(x: x, y: restY, vx: 0, vy: 0,
                                    radius: r, restY: restY,
                                    phase: Double(h % 628) / 100.0)
            }
        }
    }

    // Learned rest pose for the RAW gravity vector, so only an active lean
    // sloshes the water (any static hold — upright, flat, sim-zero — reads calm).
    private var baseX = 0.0, baseY = 0.0
    private var baseSeeded = false

    /// Advance to time `t` from the RAW device gravity vector; the rest-pose
    /// baseline is learned here. Paused freezes it (Reduce Motion / off-screen).
    func step(to t: TimeInterval, rawTiltX: Double, rawTiltY: Double, paused: Bool) {
        defer { lastT = t }
        if paused { return }
        guard lastT > 0 else { return }
        var dt = t - lastT
        if dt <= 0 || dt > 0.1 { dt = 1.0 / 60 }
        if baseSeeded {
            baseX += (rawTiltX - baseX) * 0.01
            baseY += (rawTiltY - baseY) * 0.01
        } else {
            baseX = rawTiltX; baseY = rawTiltY; baseSeeded = true
        }
        advance(dt: dt, t: t, tiltX: rawTiltX - baseX, tiltY: rawTiltY - baseY)
    }

    /// The deterministic integrator (pure — unit-tested directly).
    func advance(dt: Double, t: Double, tiltX: Double, tiltY: Double) {
        let sub = 2
        let h = dt / Double(sub)
        for _ in 0..<sub {
            for k in bodies.keys {
                var b = bodies[k]!
                let target = b.restY + bobAmp * sin(t * bobFreq + b.phase)
                var ax = tiltX * tiltScale - damp * b.vx
                var ay = -kBuoy * (b.y - target) + tiltY * tiltScale * 0.3 - damp * b.vy
                _ = ax; _ = ay
                b.vx += ax * h; b.vy += ay * h
                b.x += b.vx * h; b.y += b.vy * h
                bodies[k] = b
            }
            separate()
            clampToWater()
        }
    }

    private func separate() {
        let keys = Array(bodies.keys)
        for i in 0..<keys.count {
            for j in (i + 1)..<keys.count {
                var a = bodies[keys[i]]!, c = bodies[keys[j]]!
                let dx = c.x - a.x, dy = c.y - a.y
                let dist = max(0.001, (dx * dx + dy * dy).squareRoot())
                let minD = a.radius + c.radius + 4
                if dist < minD {
                    let push = (minD - dist) * 0.5
                    let nx = dx / dist, ny = dy / dist
                    a.x -= nx * push; a.y -= ny * push
                    c.x += nx * push; c.y += ny * push
                    bodies[keys[i]] = a; bodies[keys[j]] = c
                }
            }
        }
    }

    private func clampToWater() {
        for k in bodies.keys {
            var b = bodies[k]!
            b.x = min(max(b.x, b.radius), max(b.radius, width - b.radius))
            let top = waterTop + b.radius
            let bot = height - bottomInset - b.radius
            b.y = min(max(b.y, top), max(top, bot))
            bodies[k] = b
        }
    }

    func position(_ id: String) -> (x: Double, y: Double, r: Double)? {
        bodies[id].map { ($0.x, $0.y, $0.radius) }
    }
}
