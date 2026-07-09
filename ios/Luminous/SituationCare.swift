//
//  SituationCare.swift
//  Luminous — the on-device model reads WHERE you are, late at night
//
//  App targets only. From the coarse surroundings (reverse-geocoded place label
//  + nearby kinds + whether a station/home is near + the hour + weather), the
//  model chooses a warm line and WHICH get-home stars to offer — from a closed,
//  safe set of intents. The late-night gate and the actions themselves stay
//  code-owned; the model only phrases and selects among safe options, with a
//  deterministic fallback. Cached ≤ 1/hour.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum CareIntent: String, CaseIterable { case goHome, transit, cab, water, rest }

struct SituationRead: Equatable {
    var line: String
    var intents: [CareIntent]
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenSituation {
    @Guide(description: "一句温柔的话，像朋友在很晚的时候轻轻提醒你该回家了。不命令、不催、不吓人。")
    var line: String
    @Guide(description: "从这些里选 2 到 4 个合适的：goHome, transit, cab, water, rest")
    var intents: [String]
}
#endif

enum SituationCare {

    /// The deterministic read — used immediately and whenever the model is away.
    /// Intents come straight from what's actually available.
    static func fallback(hasStation: Bool, homeKnown: Bool) -> SituationRead {
        var intents: [CareIntent] = []
        if hasStation { intents.append(.transit) }
        if homeKnown { intents.append(.goHome) }
        intents.append(.cab)
        intents.append(.water)
        return SituationRead(line: "已经很晚了，回家的路我先帮你看着。", intents: intents)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    static func llm(hour: Int, surroundings: String, hasStation: Bool,
                    stationDist: String?, homeKnown: Bool, weather: String?) async -> SituationRead? {
        let instructions = """
        现在很晚了，用户还在外面。你像一个温柔的朋友，帮 ta 安全回家。只在\
        安全、体贴的范围内说话——提醒回家、指路、打车、喝水、就地歇一会。\
        绝不命令、不催促、不吓人。
        """
        var facts = ["现在 \(hour) 点，你还在外面"]
        if !surroundings.isEmpty { facts.append("周围：\(surroundings)") }
        if hasStation { facts.append("附近有车站\(stationDist.map { "（\($0)）" } ?? "")") }
        if homeKnown { facts.append("我知道你家的大概方向") }
        if let weather { facts.append("天气：\(weather)") }
        let prompt = facts.joined(separator: "；") + "。请给一句温柔的话，并从 "
            + "goHome, transit, cab, water, rest 里选几个此刻最贴心的。"
        guard let r = try? await LanguageModelSession(instructions: instructions)
            .respond(to: prompt, generating: GenSituation.self) else { return nil }
        let line = r.content.line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, line.count <= 40, ForbiddenWords.passes(line) else { return nil }
        let intents = r.content.intents.compactMap { CareIntent(rawValue: $0) }
        guard !intents.isEmpty else { return nil }
        // Never invent unavailable actions.
        let safe = intents.filter {
            switch $0 {
            case .transit: return hasStation
            case .goHome:  return homeKnown
            default:       return true
            }
        }
        return SituationRead(line: line, intents: safe.isEmpty ? [.cab, .water] : safe)
    }
    #endif
}

/// Holds the cached situational read for the late-night care view.
@MainActor
@Observable
final class SituationSense {
    private(set) var read: SituationRead?
    private var fetchedAt: Date?

    func refreshIfStale(hour: Int, surroundings: String, hasStation: Bool,
                        stationDist: String?, homeKnown: Bool, weather: String?) {
        if let at = fetchedAt, Date().timeIntervalSince(at) < 3600 { return }
        fetchedAt = Date()
        read = SituationCare.fallback(hasStation: hasStation, homeKnown: homeKnown)
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), AIHelper.isAvailable {
            Task { @MainActor in
                if let r = await SituationCare.llm(hour: hour, surroundings: surroundings,
                                                   hasStation: hasStation, stationDist: stationDist,
                                                   homeKnown: homeKnown, weather: weather) {
                    self.read = r
                }
            }
        }
        #endif
    }

    func forget() { read = nil; fetchedAt = nil }
}
