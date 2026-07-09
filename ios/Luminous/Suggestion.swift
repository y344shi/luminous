//
//  Suggestion.swift
//  Luminous
//
//  Gentle, context-born task suggestions — small actions the moment seems to
//  invite (a cafe right here, clear weather, a quiet desk, deep night). These
//  are *offered* as glowing icons on Home; catching one drops it into the garden.
//  Never commands, never shame; late night only ever offers calm stop-loss.
//

import Foundation

struct Suggestion: Identifiable, Hashable {
    let id: String
    let emoji: String
    let title: String
    let action: String
    let category: SeedCategory
    /// When set, this suggestion carries an EXISTING wish to a fitting nearby
    /// place (the scout) — tapping opens that wish instead of planting a new one.
    var seedId: String? = nil
    /// A soft place hint like "转角图书馆 · 200m".
    var place: String? = nil
    /// When set, this fly-by is a RELATED wish (an existing seed) that can become
    /// a moon of the orbiting wish `moonParentId` ("X"). Tapping offers the
    /// choice: moon of X, or a separate star.
    var moonParentId: String? = nil
    var moonParentTitle: String? = nil

    /// Turn a caught suggestion into a real Seed.
    func toSeed() -> Seed {
        Seed(
            id: DomainUtil.uid("seed"),
            rawText: title,
            title: title,
            description: nil,
            categories: [category],
            minimumAction: action,
            estimatedDurationMin: 10,
            energyRequired: .low,
            locationType: .anywhere,
            preferredTimes: [],
            triggerConditions: [],
            status: .active,
            createdAt: DomainUtil.nowIso(),
            updatedAt: DomainUtil.nowIso()
        )
    }
}

enum Suggester {
    /// Build up to 3 suggestions from the sensed moment. Order = relevance.
    static func suggest(
        hour: Int,
        isLateNight: Bool,
        weather: WeatherKind?,
        activity: Activity?,
        nearbyCafe: Bool,
        nearbyOuting: Bool
    ) -> [Suggestion] {
        // Late night is a hard safety gate: only calm stop-loss, never going out.
        if isLateNight {
            return [
                Suggestion(id: "s_water", emoji: "🫧", title: "喝杯水", action: "倒一杯温水，慢慢喝完", category: .recovery),
                Suggestion(id: "s_sleep", emoji: "🛏️", title: "准备睡了", action: "把灯调暗，放下手机", category: .recovery),
            ]
        }

        var pool: [Suggestion] = []
        let daytime = (8...18).contains(hour)
        let goodWeather = weather == .clear || weather == .clouds

        if nearbyCafe {
            pool.append(.init(id: "s_cafe", emoji: "☕", title: "去附近坐一会", action: "走到那家咖啡馆，点一杯", category: .recovery))
        }
        if goodWeather && daytime && activity != .transit {
            pool.append(.init(id: "s_walk", emoji: "🚶", title: "出门走几步", action: "下楼走五分钟，看看天", category: .exploration))
        }
        if nearbyOuting {
            pool.append(.init(id: "s_errand", emoji: "🛒", title: "顺路逛两分钟", action: "去附近的店随便看看", category: .exploration))
        }
        if activity == .walking || activity == .transit {
            pool.append(.init(id: "s_song", emoji: "🎧", title: "听一首歌", action: "戴上耳机，听完一整首", category: .aesthetic))
        }
        // gentle staples, always worth offering
        pool.append(.init(id: "s_write", emoji: "✏️", title: "写一句今天", action: "写下此刻心里的一句话", category: .creation))
        pool.append(.init(id: "s_reach", emoji: "🤍", title: "给一个人发句话", action: "给忽然想起的人发一句真话", category: .connection))

        return Array(pool.prefix(3))
    }
}

// MARK: - The scout: an existing wish meets a fitting place, right here

/// Watches what's within a short walk and — only when the moment suits —
/// pairs an active wish with a place that fits it ("图书馆 200m · 记三个法语
/// 单词"). Never late at night, never more than a couple, never a command.
enum OpportunityScout {

    /// A nearby place, framework-free so this stays pure and testable.
    struct Spot: Hashable {
        let name: String
        let kind: PlaceKind
        let distanceM: Double
        init(name: String, kind: PlaceKind, distanceM: Double) {
            self.name = name; self.kind = kind; self.distanceM = distanceM
        }
    }

    static func scout(seeds: [Seed],
                      spots: [Spot],
                      hour: Int,
                      isLateNight: Bool,
                      excludedPlaces: Set<String> = [],
                      limit: Int = 2) -> [Suggestion] {
        // The same appropriateness gate as the rest of the app: daytime/early
        // evening only, and the late-night rule is absolute.
        guard !isLateNight, (8...20).contains(hour), !spots.isEmpty else { return [] }

        let sorted = spots.sorted { $0.distanceM < $1.distanceM }
        var out: [Suggestion] = []
        var usedSeeds = Set<String>()
        var usedSpots = Set<Spot>()
        var usedNames = excludedPlaces      // places some other surface already shows

        for seed in seeds where seed.status == .active && !usedSeeds.contains(seed.id) {
            var kinds = Set<PlaceKind>()
            for c in seed.categories { if let a = Scoring.placeAffinity[c] { kinds.formUnion(a) } }
            guard let spot = sorted.first(where: {
                kinds.contains($0.kind) && !usedSpots.contains($0)
                    && !usedNames.contains($0.name) && $0.distanceM <= 800
            })
            else { continue }
            usedNames.insert(spot.name)
            usedSeeds.insert(seed.id)
            usedSpots.insert(spot)
            let dist = spot.distanceM < 1000
                ? "\(Int((spot.distanceM / 50).rounded()) * 50)m"
                : String(format: "%.1fkm", spot.distanceM / 1000)
            out.append(Suggestion(
                id: "scout_\(seed.id)",
                emoji: emoji(for: spot.kind),
                title: seed.title,
                action: seed.minimumAction,
                category: seed.categories.first ?? .recovery,
                seedId: seed.id,
                place: "\(spot.name) · \(dist)"
            ))
            if out.count >= limit { break }
        }
        return out
    }

    private static func emoji(for kind: PlaceKind) -> String {
        switch kind {
        case .cafe: return "☕"; case .library: return "📚"; case .park: return "🌳"
        case .market: return "🛒"; case .store: return "🛍️"; case .restaurant: return "🍴"
        case .gym: return "🏋️"; case .museum: return "🖼️"
        case .attraction: return "🎡"; case .nature: return "🏞️"
        }
    }
}
