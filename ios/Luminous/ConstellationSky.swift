//
//  ConstellationSky.swift
//  Luminous — 记忆星座: every trace becomes a star in YOUR sky
//
//  The planetarium's background stars were anonymous. Now the sky is personal:
//  each DailyTrace is a permanent star, placed deterministically (hash of its
//  id), tinted by its category, twinkling on its own phase. The most recent
//  few are joined by a faint constellation line — the shape of your week.
//  Nothing here is a score: it's just light that stays.
//
//  The birth ceremony (BirthOverlay): completing a wish sends its planet into
//  the black hole; the photon ring flares; a streak of light climbs to the
//  spot where the new star blooms. Physics-flavored: infall, flare, ejection
//  along the polar jet — the planetarium's own funeral-and-birth.
//

import SwiftUI

enum ConstellationSky {

    /// Deterministic hash → 0..<1 (stable across launches).
    private static func unit(_ s: String, _ salt: UInt64) -> Double {
        var h: UInt64 = 1469598103934665603 &+ salt
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return Double(h % 100_000) / 100_000
    }

    /// A trace's permanent place in the upper sky.
    static func position(for traceId: String, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * (0.06 + 0.88 * unit(traceId, 11)),
                y: size.height * (0.045 + 0.24 * unit(traceId, 23)))
    }

    /// Category → the star's tint. Suggestive, not spectral.
    static func tint(for category: SeedCategory?) -> Color {
        switch category {
        case .body:        return Color(red: 1.00, green: 0.78, blue: 0.62)  // warm coral
        case .creation:    return Color(red: 1.00, green: 0.90, blue: 0.60)  // gold
        case .connection:  return Color(red: 1.00, green: 0.80, blue: 0.86)  // rose
        case .exploration: return Color(red: 0.66, green: 0.92, blue: 1.00)  // cyan
        case .recovery:    return Color(red: 0.83, green: 0.80, blue: 1.00)  // lavender
        case .learning:    return Color(red: 0.75, green: 0.86, blue: 1.00)  // ice blue
        case .aesthetic:   return Color(red: 0.74, green: 1.00, blue: 0.85)  // mint
        case .none:        return .white
        }
    }

    static func starSize(for traceId: String) -> CGFloat {
        2.0 + CGFloat(unit(traceId, 37)) * 2.2
    }

    static func twinklePhase(for traceId: String) -> Double {
        unit(traceId, 53) * 2 * .pi
    }
}

/// The personal sky: one star per trace (capped to the most recent 120),
/// twinkling, with a faint line joining the newest few — the week's shape.
struct ConstellationSkyView: View {
    let traces: [DailyTrace]
    let size: CGSize
    /// A trace currently being born (its star is drawn by the overlay instead).
    var bornBeingHidden: String?

    /// Honest astronomy: stars are shy at noon and brilliant at night.
    private var strength: Double {
        let hour = Calendar.current.component(.hour, from: Date())
        switch DayGrade.phase(hour: hour) {
        case .night:        return 1.0
        case .dusk, .dawn:  return 0.8
        default:            return 0.5
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, _ in
                let shown = Array(traces.prefix(120))
                let s = strength

                // The week's constellation: join the newest few, oldest→newest.
                let recent = Array(shown.prefix(6)).reversed()
                    .filter { $0.id != bornBeingHidden }
                    .map { ConstellationSky.position(for: $0.id, in: size) }
                if recent.count >= 2 {
                    var path = Path()
                    path.move(to: recent[0])
                    for p in recent.dropFirst() { path.addLine(to: p) }
                    ctx.stroke(path, with: .color(.white.opacity(0.12 * s)), lineWidth: 0.6)
                }

                // The stars themselves.
                for trace in shown where trace.id != bornBeingHidden {
                    let p = ConstellationSky.position(for: trace.id, in: size)
                    let r = ConstellationSky.starSize(for: trace.id)
                    let phase = ConstellationSky.twinklePhase(for: trace.id)
                    let tw = (0.72 + 0.28 * sin(t * 0.9 + phase)) * s
                    let tint = ConstellationSky.tint(for: trace.category)

                    // halo
                    let halo = CGRect(x: p.x - r * 2.4, y: p.y - r * 2.4,
                                      width: r * 4.8, height: r * 4.8)
                    ctx.fill(Path(ellipseIn: halo),
                             with: .radialGradient(
                                Gradient(colors: [tint.opacity(0.32 * tw), .clear]),
                                center: p, startRadius: 0, endRadius: r * 2.4))
                    // core
                    let core = CGRect(x: p.x - r / 2, y: p.y - r / 2, width: r, height: r)
                    ctx.fill(Path(ellipseIn: core), with: .color(.white.opacity(0.9 * tw)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Demo sky (DEBUG launch argument -demoStars; simulator presentation only)

#if DEBUG
@MainActor
enum DemoSky {
    /// Plant a couple of weeks of varied traces so the constellation can be
    /// seen without living two weeks first. Never runs in release builds.
    static func plant(into store: AppStore) {
        let moments: [(String, SeedCategory)] = [
            ("出门走了五分钟，看了看天", .exploration), ("写下了心里的一句话", .creation),
            ("给妈妈发了一句真话", .connection), ("学了三个法语单词", .learning),
            ("倒了杯温水，慢慢喝完", .recovery), ("拉伸了五分钟", .body),
            ("认真看了一朵云", .aesthetic), ("在咖啡馆坐了一会", .recovery),
            ("复习了学过的词", .learning), ("拍了一张招牌来认", .learning),
            ("下楼看了夕阳", .aesthetic), ("和朋友走了一段路", .connection),
            ("画了一个小涂鸦", .creation), ("深呼吸了三次", .body),
            ("逛了逛市场", .exploration), ("听完了一整首歌", .aesthetic),
        ]
        for (i, m) in moments.enumerated() {
            let day = Calendar.current.date(byAdding: .day, value: -(i * 15) / 16, to: Date())!
            store.addTrace(DailyTrace(
                id: DomainUtil.uid("demo"),
                date: DomainUtil.localDateKey(day),
                seedId: nil, opportunityId: nil,
                text: Copy.tracePrefix + m.0,
                category: m.1, partial: i % 3 == 1,
                createdAt: DomainUtil.nowIso()))
        }
    }
}
#endif

// MARK: - The birth ceremony

/// One completion's animation state.
struct StarBirth: Equatable {
    let traceId: String
    let category: SeedCategory?
    let from: CGPoint          // where the wish's planet was
    let start: Date
    let to: CGPoint            // the star's permanent place
}

/// Fall → flare → rise → bloom, ~2.6 s, driven by TimelineView.
struct BirthOverlay: View {
    let birth: StarBirth
    let center: CGPoint        // the black hole
    var onDone: () -> Void

    private let fallEnd = 0.9, flareEnd = 1.25, riseEnd = 2.1, bloomEnd = 2.6

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSince(birth.start)
            let tint = ConstellationSky.tint(for: birth.category)
            ZStack {
                // 1 · infall: the planet spirals into the hole, shrinking.
                if t < fallEnd {
                    let p = t / fallEnd
                    let e = 1 - pow(1 - p, 2)                     // ease-in toward the hole
                    let angle = p * 2.6                            // a partial spiral wind
                    let x = birth.from.x + (center.x - birth.from.x) * e
                    let y = birth.from.y + (center.y - birth.from.y) * e
                    let sway = (1 - e) * 14
                    Circle()
                        .fill(tint.opacity(0.9))
                        .frame(width: 10 * (1 - 0.7 * e), height: 10 * (1 - 0.7 * e))
                        .blur(radius: 1)
                        .position(x: x + cos(angle) * sway, y: y + sin(angle) * sway * 0.66)
                }
                // 2 · the photon ring flares as it feeds.
                if t >= fallEnd * 0.8 && t < flareEnd + 0.3 {
                    let p = min(max((t - fallEnd * 0.8) / (flareEnd - fallEnd * 0.8), 0), 1)
                    let fade = t > flareEnd ? 1 - (t - flareEnd) / 0.3 : 1
                    Circle()
                        .stroke(tint.opacity(0.75 * fade), lineWidth: 2.5)
                        .frame(width: 96 + p * 46, height: 96 + p * 46)
                        .blur(radius: 3)
                        .position(center)
                }
                // 3 · ejection: a streak climbs the jet to the star's place.
                if t >= flareEnd && t < riseEnd {
                    let p = (t - flareEnd) / (riseEnd - flareEnd)
                    let e = p * p * (3 - 2 * p)                    // smoothstep
                    let x = center.x + (birth.to.x - center.x) * e
                    let y = center.y + (birth.to.y - center.y) * e
                    let dx = birth.to.x - center.x, dy = birth.to.y - center.y
                    let ang = atan2(dy, dx)
                    Capsule()
                        .fill(LinearGradient(colors: [tint.opacity(0), .white.opacity(0.9)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: 46, height: 2)
                        .rotationEffect(.radians(ang))
                        .position(x: x, y: y)
                        .blur(radius: 0.5)
                }
                // 4 · bloom: the star is born, overshooting softly then settling.
                if t >= riseEnd {
                    let p = min((t - riseEnd) / (bloomEnd - riseEnd), 1)
                    let scale = 1 + 2.2 * (1 - p) * sin(p * .pi)
                    Circle()
                        .fill(RadialGradient(colors: [.white.opacity(0.95), tint.opacity(0.4), .clear],
                                             center: .center, startRadius: 0, endRadius: 9))
                        .frame(width: 18, height: 18)
                        .scaleEffect(scale)
                        .position(birth.to)
                }
            }
            .allowsHitTesting(false)
            .onChange(of: t >= bloomEnd) { _, done in
                if done { onDone() }
            }
        }
    }
}
