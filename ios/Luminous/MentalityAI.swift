//
//  MentalityAI.swift
//  Luminous — the on-device model reads the day's aggregates (app targets only)
//
//  Input is only what the histograms already hold: dwell minutes, transition
//  counts, weather, today's outcomes. Output is the three soft 0–10 dials of
//  MentalityEstimate. Cached for an hour; degrades to nil (= neutral, zero
//  scoring effect) whenever the model is unavailable. Never surfaced as a
//  label — the no-diagnosis rule covers implied diagnoses too.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenMentality {
    @Guide(description: "坐立不安的程度，0（很安定）到 10（很躁动）")
    var restlessness: Int
    @Guide(description: "消耗/疲惫的程度，0（很有余力）到 10（几乎耗尽）")
    var depletion: Int
    @Guide(description: "对新事物的开放程度，0（只想缩着）到 10（想探出去）")
    var openness: Int
}
#endif

extension AppStore {

    /// Refresh the transient mentality estimate if it's stale (>1 h) and the
    /// model is available. Fire-and-forget; scoring uses whatever is cached.
    func refreshMentalityIfStale() {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *), AIHelper.isAvailable else { return }
        if let at = mentalityFetchedAt, Date().timeIntervalSince(at) < 3600 { return }
        mentalityFetchedAt = Date()          // claim the slot before the async hop
        let summary = daySummaryForMentality()
        Task { @MainActor in
            let instructions = """
            你根据一天的粗略节奏数据，安静地估计此刻的状态。只看数据，不评判、\
            不诊断、不给建议。宁可居中，不要夸张。
            """
            let prompt = """
            今天到现在的节奏：\(summary)。
            请用三个 0-10 的数字描述此刻大概的状态。
            """
            guard let r = try? await LanguageModelSession(instructions: instructions)
                .respond(to: prompt, generating: GenMentality.self) else { return }
            mentality = MentalityEstimate(
                restlessness: Double(r.content.restlessness) / 10,
                depletion: Double(r.content.depletion) / 10,
                openness: Double(r.content.openness) / 10)
        }
        #endif
    }

    /// The day, compressed to one factual line the model can read.
    private func daySummaryForMentality() -> String {
        var bits: [String] = []
        if let dwell = todayDwellLine() { bits.append(dwell) }
        if let p = persistence {
            let start = Calendar.current.startOfDay(for: Date())
            let transitions = p.events(profile: activeProfileID, since: start,
                                       kindPrefix: "sense.activity").count
            bits.append("状态切换 \(transitions) 次")
            let outcomes = p.events(profile: activeProfileID, since: start,
                                    kindPrefix: "outcome.")
            let done = outcomes.filter { !$0.kind.hasSuffix("skipped") }.count
            let skipped = outcomes.count - done
            if outcomes.count > 0 { bits.append("做了 \(done) 件小事，跳过 \(skipped) 件") }
        }
        if let w = lastContext?.weatherKind { bits.append("天气 \(w.rawValue)") }
        let hour = Calendar.current.component(.hour, from: Date())
        bits.append("现在 \(hour) 点")
        return bits.joined(separator: "；")
    }
}
