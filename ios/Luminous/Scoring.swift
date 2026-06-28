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

    static func scoreSeed(_ seed: Seed, _ ctx: ContextSnapshot, rng: Rng = { Double.random(in: 0..<1) }) -> ScoreBreakdown {
        let tf = timeFit(seed, ctx)
        let df = durationFit(seed, ctx)
        let ef = energyFit(seed, ctx)
        let lf = locationFit(seed, ctx)
        let mf = moodFit(seed, ctx)
        let fr = freshness(seed)
        let ser = rng()

        var total = tf * 0.2 + df * 0.2 + ef * 0.2 + lf * 0.2 + mf * 0.1 + fr * 0.05 + ser * 0.05
        total += triggerBonus(seed, ctx)
        if ctx.isLateNight && isRescueSeed(seed) { total += 0.5 }

        return ScoreBreakdown(
            timeFit: tf, durationFit: df, energyFit: ef, locationFit: lf,
            moodFit: mf, freshness: fr, serendipity: ser,
            total: DomainUtil.clamp(total, 0, 2)
        )
    }

    /// Rank active/sleeping seeds for the current context.
    static func rankSeeds(_ seeds: [Seed], _ ctx: ContextSnapshot, rng: Rng = { Double.random(in: 0..<1) }, limit: Int = 3) -> [ScoredSeed] {
        var candidates = seeds.filter { $0.status == .active || $0.status == .sleeping }

        if ctx.isLateNight {
            let safe = candidates.filter { !isUnsafeLateNight($0) }
            candidates = safe.isEmpty ? candidates : safe
        }

        var scored = candidates.map { seed -> ScoredSeed in
            let breakdown = scoreSeed(seed, ctx, rng: rng)
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
    static func recommend(_ seeds: [Seed], _ ctx: ContextSnapshot, rng: Rng = { Double.random(in: 0..<1) }, limit: Int = 3) -> [Opportunity] {
        rankSeeds(seeds, ctx, rng: rng, limit: limit).map { s in
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
