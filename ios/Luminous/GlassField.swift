//
//  GlassField.swift
//  Luminous — Direction A · Liquid Glass
//
//  A dreamy floating field of glass bubbles rendered behind the Home content.
//  iOS port of the web `BubbleField` + glass filters:
//    glass 1 refraction      → soft radial cores that bend light (gradient lensing)
//    glass 2 caustic rim     → hue-shifting specular rim + a slow sweeping glint
//    glass 3 depth field     → far bubbles smaller/dimmer/blurred, near ones crisp
//    glass 4 gooey coalesce  → alphaThreshold+blur metaball merge under the glass
//    glass 5 dreamier         → calm drift, drifting light motes, gentle vignette
//
//  Pure SwiftUI: TimelineView + Canvas, no external deps. Honors Reduce Motion.
//

import SwiftUI

// MARK: - Model

/// One glass bubble. `depth` 0 (far) → 1 (near) drives size, brightness, blur.
struct GlassBubble: Identifiable {
    let id = Int.random(in: 0 ... .max)
    var origin: CGPoint      // 0...1 normalized home position
    var depth: CGFloat       // 0 far … 1 near
    var driftPhase: CGFloat  // de-syncs the sine drift
    var driftAmp: CGFloat    // normalized drift amplitude

    /// A calm, hand-tuned field: a few large near bubbles up top by the orb,
    /// many smaller dim ones scattered across — mirrors the web layout.
    static let field: [GlassBubble] = {
        let seeds: [(CGFloat, CGFloat, CGFloat)] = [
            // x,    y,    depth
            (0.50, 0.18, 1.00), (0.28, 0.30, 0.82), (0.74, 0.28, 0.86),
            (0.16, 0.52, 0.55), (0.86, 0.50, 0.60), (0.40, 0.60, 0.48),
            (0.62, 0.68, 0.44), (0.24, 0.78, 0.34), (0.80, 0.76, 0.36),
            (0.50, 0.88, 0.30), (0.10, 0.84, 0.26), (0.92, 0.86, 0.24),
        ]
        return seeds.enumerated().map { i, s in
            GlassBubble(
                origin: CGPoint(x: s.0, y: s.1),
                depth: s.2,
                driftPhase: CGFloat(i) * 0.7,
                driftAmp: 0.012 + CGFloat(i % 3) * 0.006
            )
        }
    }()

    func center(at t: TimeInterval, in size: CGSize, motion: CGFloat, buoyancy: Bool = false) -> CGPoint {
        let tt = CGFloat(t)
        if buoyancy {
            // Ocean: the bottom edge is the floor; bubbles rise toward the top
            // surface. The most relevant (highest depth) settle highest, all
            // sway sideways a touch and bob gently up/down.
            let restY = 0.14 + (1 - depth) * 0.66
            let bob = sin(tt * 0.5 + driftPhase) * (0.018 + driftAmp) * motion
            let sway = sin(tt * 0.22 + driftPhase * 1.3) * driftAmp * 1.5 * motion
            return CGPoint(x: (origin.x + sway) * size.width,
                           y: (restY + bob) * size.height)
        }
        let dx = sin(tt * 0.18 + driftPhase) * driftAmp * motion
        let dy = cos(tt * 0.14 + driftPhase * 1.3) * driftAmp * motion
        return CGPoint(x: (origin.x + dx) * size.width,
                       y: (origin.y + dy) * size.height)
    }

    func radius(in size: CGSize) -> CGFloat {
        let base = min(size.width, size.height)
        return base * (0.05 + depth * 0.16)
    }
}

// MARK: - View

struct GlassField: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var bubbles: [GlassBubble] = GlassBubble.field
    /// When true the field reads as an ocean: bubbles rise from the floor
    /// (bottom edge) toward the surface (top) instead of drifting in place.
    var buoyancy: Bool = false

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { tl in
                let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    drawGooeyCores(in: &ctx, size: size, t: t)   // glass 4 metaballs
                    drawGlassRims(in: &ctx, size: size, t: t)    // glass 1+2 refraction+caustics
                    drawMotes(in: &ctx, size: size, t: t)        // glass 5 motes
                }
                .drawingGroup()
            }
            .ignoresSafeArea()

            vignette.ignoresSafeArea()   // glass 5 vignette
        }
        .accessibilityHidden(true)
    }

    // glass 4 — soft cores merged through an alphaThreshold goo layer.
    private func drawGooeyCores(in ctx: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        var layer = ctx
        layer.addFilter(.blur(radius: min(size.width, size.height) * 0.04))
        layer.addFilter(.alphaThreshold(min: 0.45, color: theme.accentSoft.opacity(0.55)))
        for b in bubbles {
            let c = b.center(at: t, in: size, motion: motion, buoyancy: buoyancy)
            let r = b.radius(in: size) * 0.92
            let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
            layer.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.9)))
        }
    }

    // glass 1+2+3 — each bubble: a refractive core gradient, a hue-shifting caustic
    // rim, a sweeping glint, and depth-based blur for the far ones.
    private func drawGlassRims(in ctx: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let sweep = (sin(CGFloat(t) * 0.3) * 0.5 + 0.5)   // 0…1 moving glint
        for b in bubbles {
            let c = b.center(at: t, in: size, motion: motion, buoyancy: buoyancy)
            let r = b.radius(in: size)
            let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)

            var layer = ctx
            // glass 3: far bubbles get progressive blur, near ones are crisp.
            let blur = (1 - b.depth) * r * 0.18
            if blur > 0.5 { layer.addFilter(.blur(radius: blur)) }

            // refractive core: bright off-center highlight fading to clear.
            let core = GraphicsContext.Shading.radialGradient(
                Gradient(colors: [
                    Color.white.opacity(0.55 * b.depth + 0.12),
                    theme.surface.opacity(0.20 * b.depth),
                    Color.clear,
                ]),
                center: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.35),
                startRadius: 0, endRadius: r * 1.05)
            layer.fill(Path(ellipseIn: rect), with: core)

            // caustic rim: a thin hue-shifting specular ring.
            let hue = (b.driftPhase / 6.28 + CGFloat(t) * 0.02).truncatingRemainder(dividingBy: 1)
            let rim = Color(hue: Double(hue), saturation: 0.35, brightness: 1.0)
                .opacity(0.5 * b.depth + 0.1)
            layer.stroke(Path(ellipseIn: rect.insetBy(dx: 1, dy: 1)),
                         with: .color(rim), lineWidth: max(1, r * 0.05))

            // sweeping glint: a short bright arc that travels around the rim.
            let glintAngle = Angle(radians: Double(sweep * 6.28 + b.driftPhase))
            let gx = c.x + cos(glintAngle.radians) * r * 0.92
            let gy = c.y + sin(glintAngle.radians) * r * 0.92
            let gRect = CGRect(x: gx - r * 0.18, y: gy - r * 0.18, width: r * 0.36, height: r * 0.36)
            layer.fill(Path(ellipseIn: gRect),
                       with: .radialGradient(
                        Gradient(colors: [Color.white.opacity(0.8 * b.depth), .clear]),
                        center: CGPoint(x: gx, y: gy), startRadius: 0, endRadius: r * 0.18))
        }
    }

    // glass 5 — faint drifting light motes.
    private func drawMotes(in ctx: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let count = 18
        for i in 0 ..< count {
            let fi = CGFloat(i)
            let x = (sin(fi * 12.9898) * 43758.547).truncatingRemainder(dividingBy: 1)
            let baseX = abs(x) * size.width
            let speed = 0.004 + (fi.truncatingRemainder(dividingBy: 5)) * 0.002
            let y = size.height * (1 - ((CGFloat(t) * speed + fi * 0.13).truncatingRemainder(dividingBy: 1)))
            let r = 1.0 + (fi.truncatingRemainder(dividingBy: 3))
            let twinkle = 0.25 + 0.25 * sin(CGFloat(t) * 0.8 + fi)
            ctx.fill(Path(ellipseIn: CGRect(x: baseX, y: y, width: r, height: r)),
                     with: .color(theme.textMuted.opacity(Double(twinkle))))
        }
    }

    private var vignette: some View {
        RadialGradient(
            gradient: Gradient(colors: [.clear, theme.background.opacity(0.0), theme.background.opacity(0.55)]),
            center: .center, startRadius: 40, endRadius: 520)
    }

    private var motion: CGFloat { reduceMotion ? 0 : 1 }
}

#Preview {
    GlassField()
        .environment(\.theme, Theme.tokens(for: .duskGarden))
}
