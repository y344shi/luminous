//
//  OceanField.swift
//  Luminous — the ocean skin's home: wishes float in a liquid that sloshes
//  with the gyro. Volume is relevance; bigger, more-relevant wishes float
//  higher. Small wishes stay reachable. Driven by the pure OceanSim.
//

import SwiftUI

struct OceanField: View {
    struct Item: Identifiable { let id: String; let seed: Seed; let importance: Double }
    let items: [Item]
    let size: CGSize
    let tilt: CGSize                       // raw sensed.gravity
    var onTap: (String) -> Void            // seed id
    var glyph: (Seed) -> String

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sim = OceanSim()

    private var waterTop: CGFloat { size.height * 0.34 }

    var body: some View {
        ZStack {
            water
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let _ = stepOcean(t)
                ForEach(items) { it in
                    if let p = sim.position(it.seed.id) {
                        bubble(it.seed, r: CGFloat(p.r))
                            .position(x: CGFloat(p.x), y: CGFloat(p.y))
                            .onTapGesture { onTap(it.id) }
                    }
                }
                if items.isEmpty {
                    Text("今天的水面很静。捞一个念头吧。")
                        .font(.system(size: 14)).foregroundStyle(theme.textSecondary)
                        .position(x: size.width / 2, y: waterTop + 60)
                }
            }
        }
    }

    private func stepOcean(_ t: TimeInterval) {
        sim.sync(items.map { ($0.seed.id, $0.importance) },
                 waterTop: Double(waterTop),
                 width: Double(size.width), height: Double(size.height))
        sim.step(to: t, rawTiltX: Double(tilt.width), rawTiltY: Double(tilt.height),
                 paused: reduceMotion)
    }

    // The water: a soft depth gradient under a brighter surface band.
    private var water: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: waterTop)
            LinearGradient(
                colors: [theme.accentSoft.opacity(0.45), theme.accent.opacity(0.22),
                         theme.surface.opacity(0.35)],
                startPoint: .top, endPoint: .bottom)
                .overlay(Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(height: 2), alignment: .top)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func bubble(_ seed: Seed, r: CGFloat) -> some View {
        ZStack {
            Circle().fill(RadialGradient(
                colors: [.white.opacity(0.5), theme.accentSoft.opacity(0.6),
                         theme.accent.opacity(0.35)],
                center: UnitPoint(x: 0.36, y: 0.30), startRadius: 0, endRadius: r))
            Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1)
            Image(systemName: glyph(seed))
                .font(.system(size: r * 0.42, weight: .light))
                .foregroundStyle(theme.textPrimary)
            if r > 34 {
                Text(seed.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1).fixedSize()
                    .offset(y: r + 9)
            }
        }
        .frame(width: r * 2, height: r * 2)
    }
}
