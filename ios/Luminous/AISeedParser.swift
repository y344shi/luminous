//
//  AISeedParser.swift
//  Luminous — the on-device model catches the wish; keywords are the net
//
//  The keyword SeedParser only understands ~8 patterns; real wishes are richer
//  ("想在雨天给妈妈写封信"). Here the on-device LLM parses the raw text into the
//  full SeedDraft — categories, a truly tiny minimum action, duration, energy,
//  place, times, triggers — with the app's tone rules as hard instructions.
//  Deterministic guardrails: every field is validated against the closed enums,
//  the text fields must pass ForbiddenWords, and any failure falls back to the
//  keyword parser. The LLM proposes; the code disposes.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenSeedDraft {
    @Guide(description: "一个短标题（≤16字），保留愿望的原味，去掉“我想/我要”前缀")
    var title: String
    @Guide(description: "1-2 个类别，只能从这些里选：body, creation, connection, exploration, recovery, learning, aesthetic")
    var categories: [String]
    @Guide(description: "最小的一步：小到现在就能开始、5分钟内能做完的一个动作。温柔、具体、绝不是作业")
    var minimumAction: String
    @Guide(description: "大概需要的分钟数，5 到 60 之间")
    var durationMin: Int
    @Guide(description: "需要的力气，只能是：low, medium, high")
    var energy: String
    @Guide(description: "适合的地点，只能是：anywhere, home, work, outdoor, downtown, computer, transit")
    var location: String
    @Guide(description: "适合的时段，0-2 个，只能从：morning, lunch, afternoon, after_work, evening, weekend 里选（不要选 late_night）")
    var times: [String]
}
#endif

enum AISeedParser {

    /// Parse a raw wish. Tries the on-device model; falls back to the keyword
    /// parser on any unavailability, invalid field, or forbidden word.
    static func parse(_ raw: String) async -> SeedDraft {
        let fallback = SeedParser.parse(raw)
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), AIHelper.isAvailable {
            if let ai = await llmParse(raw, fallback: fallback) { return ai }
        }
        #endif
        return fallback
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private static func llmParse(_ raw: String, fallback: SeedDraft) async -> SeedDraft? {
        let instructions = """
        你在帮一个「生活锚点」应用接住一个轻轻的愿望。它不是待办事项，没有截止日期、\
        没有优先级、没有打卡。你的工作：读懂这句话，把它整理成一个温柔的愿望卡片。\
        「最小的一步」要小到现在就能开始；语气永远不催促、不布置作业、不评判。
        """
        let prompt = "愿望原文：「\(raw.trimmingCharacters(in: .whitespacesAndNewlines))」"
        guard let r = try? await LanguageModelSession(instructions: instructions)
            .respond(to: prompt, generating: GenSeedDraft.self) else { return nil }
        let g = r.content

        // Deterministic validation — anything off falls back to the keyword net.
        let cats = g.categories.compactMap { SeedCategory(rawValue: $0) }
        guard !cats.isEmpty else { return nil }
        let title = String(g.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(16))
        let action = g.minimumAction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !action.isEmpty,
              ForbiddenWords.passes(title), ForbiddenWords.passes(action) else { return nil }
        let times = g.times.compactMap { SemanticTime(rawValue: $0) }
            .filter { $0 != .lateNight }                       // never schedule the night

        var draft = fallback                                    // keyword net fills gaps
        draft.title = title
        draft.categories = Array(cats.prefix(2))
        draft.minimumAction = action
        draft.estimatedDurationMin = min(max(g.durationMin, 5), 60)
        draft.energyRequired = Energy(rawValue: g.energy) ?? fallback.energyRequired
        draft.locationType = LocationType(rawValue: g.location) ?? fallback.locationType
        if !times.isEmpty { draft.preferredTimes = Array(times.prefix(2)) }
        return draft
    }
    #endif
}
