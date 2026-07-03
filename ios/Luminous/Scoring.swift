//
//  Scoring.swift
//  Luminous
//
//  The recommender: rank active seeds for the current context.
//  Pure, rng-injectable. Late-night safety is a hard gate. Ported from lib/scoring.ts.
//

import Foundation

typealias Rng = () -> Double

struct ScoreBreakdown {
    var timeFit: Double
    var durationFit: Double
    var energyFit: Double
    var locationFit: Double
    var moodFit: Double
    var freshness: Double
    var serendipity: Double
    var total: Double
}

struct ScoredSeed {
    var seed: Seed
    var breakdown: ScoreBreakdown
    var reason: String
    var suggestedAction: String
}

enum Scoring {
    private static let energyRank: [Energy: Int] = [.low: 0, .medium: 1, .high: 2]

    /// Which categories each mood gently leans toward.
    private static let moodAffinity: [Mood: [SeedCategory]] = [
        .empty: [.recovery, .connection, .body, .aesthetic],
        .tired: [.body, .recovery],
        .anxious: [.body, .recovery, .exploration],
        .okay: [.learning, .creation, .exploration, .aesthetic],
        .alive: [.exploration, .aesthetic, .creation],
        .avoidant: [.creation, .learning],
        .lonely: [.connection, .recovery, .body],
        .wantLove: [.connection, .recovery, .body],
        .unknown: [],
    ]

    private static let semanticTimeLabel: [SemanticTime: String] = [
        .morning: "早上",
        .lunch: "中午",
        .afternoon: "下午",
        .afterWork: "傍晚",
        .evening: "晚上",
        .lateNight: "深夜",
        .weekend: "周末",
    ]

    // MARK: - Individual fits

    private static func timeFit(_ seed: Seed, _ ctx: ContextSnapshot) -> Double {
        if seed.preferredTimes.isEmpty { return 0.6 }
        if seed.preferredTimes.contains(ctx.semanticTime) { return 1 }
        if ctx.isWeekend == true && seed.preferredTimes.contains(.weekend) { return 1 }
        return 0.3
    }

    private static func durationFit(_ seed: Seed, _ ctx: ContextSnapshot) -> Double {
        guard let free = ctx.freeMinutes else { return 0.6 }
        if free >= seed.estimatedDurationMin { return 1 }
        if Double(free) >= Double(seed.estimatedDurationMin) / 3 { return 0.65 }
        if free >= 5 { return 0.35 }
        return 0.1
    }

    private static func energyFit(_ seed: Seed, _ ctx: ContextSnapshot) -> Double {
        let need = energyRank[seed.energyRequired] ?? 0
        let have = energyRank[ctx.energy] ?? 0
        if have >= need { return 1 }
        if need - have == 1 { return 0.4 }
        return 0.1
    }

    private static func locationFit(_ seed: Seed, _ ctx: ContextSnapshot) -> Double {
        if seed.locationType == .anywhere { return 1 }
        let hint = ctx.locationHint
        if hint == nil || hint == .unknown {
            if seed.locationType == .downtown || seed.locationType == .outdoor { return 0.45 }
            return 0.6
        }
        if hint == seed.locationType { return 1 }
        if seed.locationType == .computer && hint == .home { return 0.8 }
        if seed.locationType == .home && hint == .computer { return 0.8 }
        return 0.2
    }

    private static func moodFit(_ seed: Seed, _ ctx: ContextSnapshot) -> Double {
        let prefs = moodAffinity[ctx.mood] ?? []
        if prefs.isEmpty { return 0.6 }
        let overlap = seed.categories.contains { prefs.contains($0) }
        return overlap ? 1 : 0.3
    }

    private static func freshness(_ seed: Seed) -> Double {
        if seed.status == .sleeping { return 0.5 }
        if seed.status == .active { return 1 }
        return 0
    }

    /// Additive bonus when a seed's trigger conditions match the live context.
    static func triggerBonus(_ seed: Seed, _ ctx: ContextSnapshot) -> Double {
        var bonus = 0.0
        func has(_ t: String) -> Bool { seed.triggerConditions.contains(t) }
        let short = ctx.freeMinutes != nil && ctx.freeMinutes! <= 15

        if has("avoidant_mood") && ctx.mood == .avoidant { bonus += 0.18 }
        if has("lonely") && ctx.mood == .lonely { bonus += 0.18 }
        if has("want_love") && (ctx.mood == .wantLove || ctx.mood == .lonely) { bonus += 0.18 }
        if has("low_energy_ok") && ctx.energy == .low { bonus += 0.06 }
        if has("short_free_time") && short { bonus += 0.08 }
        if has("free_time_15min"), let f = ctx.freeMinutes, f >= 15 { bonus += 0.04 }
        if has("weather_good") && ctx.isOutdoorWeatherGood == true { bonus += 0.1 }
        if has("near_outdoor") && ctx.locationHint == .outdoor { bonus += 0.1 }
        if has("at_computer") && ctx.deviceContext?.isAtComputer == true { bonus += 0.06 }
        if (has("late_night") || has("rescue_mode")) && ctx.isLateNight { bonus += 0.2 }
        if has("not_late_night") && ctx.isLateNight { bonus -= 0.3 }

        return bonus
    }

    /// Additive bonus from the on-device senses (motion / loudness / arousal).
    /// Ported verbatim from `@core/scoring`. Clamped to ±0.25.
    static func sensorBonus(_ seed: Seed, _ ctx: ContextSnapshot) -> Double {
        var b = 0.0
        let cats = Set(seed.categories)
        let focus = cats.contains(.learning) || cats.contains(.creation)

        switch ctx.activity {
        case .transit:
            if seed.estimatedDurationMin <= 10 { b += 0.1 }
            if focus && seed.locationType == .computer { b -= 0.12 }
            if cats.contains(.recovery) || cats.contains(.body) { b += 0.05 }
        case .walking:
            if seed.locationType == .outdoor || cats.contains(.exploration) || cats.contains(.body) { b += 0.1 }
        case .still:
            if focus { b += 0.05 }
        case .none: break
        }

        switch ctx.ambient {
        case .quiet:
            if focus || cats.contains(.aesthetic) { b += 0.1 }
        case .lively:
            if cats.contains(.connection) { b += 0.1 }
            if cats.contains(.recovery) { b += 0.05 }
            if focus { b -= 0.06 }
        case .none: break
        }

        switch ctx.arousal {
        case .elevated:
            if cats.contains(.recovery) || cats.contains(.body) { b += 0.12 }
            if ctx.energy == .high || cats.contains(.exploration) { b -= 0.08 }
        case .calm:
            if focus { b += 0.06 }
        case .none: break
        }

        return DomainUtil.clamp(b, -0.25, 0.25)
    }

    /// Which nearby place kinds suit each wish category (do it *somewhere that fits*).
    static let placeAffinity: [SeedCategory: Set<PlaceKind>] = [
        .learning:    [.library, .cafe, .museum],
        .creation:    [.library, .cafe, .nature],
        .connection:  [.cafe, .restaurant, .attraction],
        .exploration: [.store, .market, .museum, .attraction, .nature],
        .aesthetic:   [.park, .museum, .cafe, .nature, .attraction],
        .body:        [.park, .gym, .nature],
        .recovery:    [.cafe, .park, .nature],
    ]

    /// Bonus when a fitting place is within a short walk (learn French → a nearby
    /// cafe/library). Gated by the late-night safety rule (never push going out).
    static func placeBonus(_ seed: Seed, _ ctx: ContextSnapshot) -> Double {
        guard !ctx.isLateNight, let kinds = ctx.nearbyKinds, !kinds.isEmpty else { return 0 }
        let near = Set(kinds)
        for cat in seed.categories {
            if let aff = placeAffinity[cat], !aff.isDisjoint(with: near) { return 0.12 }
        }
        return 0
    }

    /// True if this seed is UNSAFE to recommend late at night.
    static func isUnsafeLateNight(_ seed: Seed) -> Bool {
        if seed.triggerConditions.contains("late_night") || seed.triggerConditions.contains("rescue_mode") {
            return false
        }
        if seed.locationType == .outdoor || seed.locationType == .downtown { return true }
        if seed.categories.contains(.exploration) { return true }
        if seed.energyRequired == .high { return true }
        if seed.estimatedDurationMin > 20 { return true }
        return false
    }

    private static func isRescueSeed(_ seed: Seed) -> Bool {
        seed.triggerConditions.contains("late_night")
            || seed.triggerConditions.contains("rescue_mode")
            || (seed.energyRequired == .low
                && seed.estimatedDurationMin <= 15
                && seed.categories.contains { $0 == .body || $0 == .recovery })
    }

    private static func buildReason(_ seed: Seed, _ ctx: ContextSnapshot, _ b: ScoreBreakdown) -> String {
        if ctx.isLateNight {
            return "现在已经很晚了，这是一个不费力的止损动作。完成它，今天就没有完全消失。"
        }
        var bits: [String] = []
        if b.durationFit >= 0.9, let free = ctx.freeMinutes {
            bits.append("你现在大概有 \(free) 分钟，刚好够")
        } else if ctx.energy == .low {
            bits.append("你现在不需要很大力气，只要离开屏幕一会儿")
        }
        if b.moodFit >= 0.9 {
            if ctx.mood == .lonely || ctx.mood == .wantLove {
                bits.append("它能让你和世界重新有一点连接")
            } else if ctx.mood == .anxious {
                bits.append("它能让你慢下来一点")
            } else if ctx.mood == .empty {
                bits.append("它能让你重新有一点在场的感觉")
            } else if ctx.mood == .avoidant {
                bits.append("它很小，小到可以现在就开始")
            }
        }
        if bits.isEmpty {
            let tl = semanticTimeLabel[ctx.semanticTime] ?? "现在"
            bits.append("\(tl)刚好适合做一点点")
        }
        return bits.joined(separator: "，") + "。"
    }

    // MARK: - Scoring

    /// Serendipity that holds still: a hash of (seed, part of day), so two opens
    /// a minute apart agree with each other, but tomorrow evening differs.
    static func stableSerendipity(_ seedId: String, _ slot: String) -> Double {
        var h: UInt64 = 5381
        for b in "\(seedId)|\(slot)".utf8 { h = h &* 33 &+ UInt64(b) }
        return Double(h % 10_000) / 10_000
    }

    static func scoreSeed(_ seed: Seed, _ ctx: ContextSnapshot,
                          rng: Rng? = nil,
                          history: Recurrence.SeedStats? = nil,
                          mentality: MentalityEstimate? = nil) -> ScoreBreakdown {
        let tf = timeFit(seed, ctx)
        let df = durationFit(seed, ctx)
        let ef = energyFit(seed, ctx)
        let lf = locationFit(seed, ctx)
        let mf = moodFit(seed, ctx)
        let fr = freshness(seed)
        let ser = rng?() ?? stableSerendipity(seed.id, ctx.semanticTime.rawValue)

        var total = tf * 0.2 + df * 0.2 + ef * 0.2 + lf * 0.2 + mf * 0.1 + fr * 0.05 + ser * 0.05
        total += triggerBonus(seed, ctx)
        total += sensorBonus(seed, ctx)
        total += placeBonus(seed, ctx)
        total += Recurrence.historyBonus(seed, ctx, stats: history)
        total += Mentality.bonus(seed, estimate: mentality)
        if ctx.isLateNight && isRescueSeed(seed) { total += 0.5 }

        return ScoreBreakdown(
            timeFit: tf, durationFit: df, energyFit: ef, locationFit: lf,
            moodFit: mf, freshness: fr, serendipity: ser,
            total: DomainUtil.clamp(total, 0, 2)
        )
    }

    /// Rank active/sleeping seeds for the current context.
    static func rankSeeds(_ seeds: [Seed], _ ctx: ContextSnapshot,
                          rng: Rng? = nil,
                          history: [String: Recurrence.SeedStats] = [:],
                          mentality: MentalityEstimate? = nil,
                          limit: Int = 3) -> [ScoredSeed] {
        var candidates = seeds.filter { $0.status == .active || $0.status == .sleeping }

        if ctx.isLateNight {
            let safe = candidates.filter { !isUnsafeLateNight($0) }
            candidates = safe.isEmpty ? candidates : safe
        }

        var scored = candidates.map { seed -> ScoredSeed in
            let breakdown = scoreSeed(seed, ctx, rng: rng, history: history[seed.id],
                                      mentality: mentality)
            return ScoredSeed(
                seed: seed,
                breakdown: breakdown,
                reason: buildReason(seed, ctx, breakdown),
                suggestedAction: seed.minimumAction
            )
        }

        scored.sort { $0.breakdown.total > $1.breakdown.total }
        return Array(scored.prefix(limit))
    }

    /// Convert scored seeds into Opportunity records ready for the UI.
    static func recommend(_ seeds: [Seed], _ ctx: ContextSnapshot,
                          rng: Rng? = nil,
                          history: [String: Recurrence.SeedStats] = [:],
                          mentality: MentalityEstimate? = nil,
                          limit: Int = 3) -> [Opportunity] {
        rankSeeds(seeds, ctx, rng: rng, history: history, mentality: mentality,
                  limit: limit).map { s in
            Opportunity(
                id: DomainUtil.uid("opp"),
                seedId: s.seed.id,
                score: s.breakdown.total,
                reason: s.reason,
                suggestedAction: s.suggestedAction,
                notificationText: "\(s.seed.title) · \(s.seed.minimumAction)",
                createdAt: DomainUtil.nowIso()
            )
        }
    }
}
