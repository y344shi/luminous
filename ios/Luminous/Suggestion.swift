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
