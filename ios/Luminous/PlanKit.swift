//
//  PlanKit.swift
//  Luminous — a wish breaks into tiny steps, each carrying a real resource
//
//  Pure and Foundation-only (in the SwiftPM test package). The LLM proposes a
//  gentle 2–4 step breakdown (TaskPlannerAI.swift); everything it says passes
//  through here: closed resource set, length caps, ForbiddenWords, and a
//  deterministic fallback plan so the card never comes up empty-handed.
//  Steps are invitations, not homework — no numbering pressure, no deadlines.
//
//  Resources a step can carry:
//    route  → a fitting nearby place + walking time (Maps)
//    vocab  → a themed set of words to learn right now
//    photo  → the camera translator
//    breath → the 3-breath script
//    none   → just a tiny step
//

import Foundation

enum PlanResource: String, CaseIterable, Hashable {
    case route, vocab, photo, breath, none
}

struct PlanStep: Hashable, Identifiable {
    let title: String        // the tiny step, ≤24 chars
    let resource: PlanResource
    let detail: String       // resource hint: vocab theme / route flavor, ≤16 chars
    var id: String { title + resource.rawValue }
    init(title: String, resource: PlanResource, detail: String = "") {
        self.title = title; self.resource = resource; self.detail = detail
    }
}

enum PlanKit {

    /// Validate raw (LLM-proposed) steps into a safe plan: closed resource set,
    /// caps, word filter, 2…4 steps. Returns nil when too little survives —
    /// the caller then uses `fallback`.
    static func validate(_ raw: [(title: String, resource: String, detail: String)]) -> [PlanStep]? {
        var out: [PlanStep] = []
        for r in raw {
            let title = r.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, title.count <= 24,
                  ForbiddenWords.passes(title + r.detail),
                  let res = PlanResource(rawValue: r.resource) else { continue }
            let step = PlanStep(title: String(title.prefix(24)),
                                resource: res,
                                detail: String(r.detail.prefix(16)))
            if !out.contains(step) { out.append(step) }
            if out.count == 4 { break }
        }
        return out.count >= 2 ? out : nil
    }

    /// The deterministic plan when the model is away: the seed's own minimum
    /// action, plus the resource its nature suggests. Never empty.
    static func fallback(for seed: Seed) -> [PlanStep] {
        var steps = [PlanStep(title: seed.minimumAction, resource: .none)]
        let cats = Set(seed.categories)
        if cats.contains(.learning) {
            steps.append(PlanStep(title: "让 AI 挑几个此刻用得上的词", resource: .vocab))
            steps.append(PlanStep(title: "拍一张身边的文字来认", resource: .photo))
        }
        if cats.contains(.exploration) || cats.contains(.body) || seed.locationType == .outdoor {
            steps.append(PlanStep(title: "找一个合适的地方", resource: .route))
        }
        if cats.contains(.recovery) {
            steps.append(PlanStep(title: "先呼吸三次", resource: .breath))
        }
        return Array(steps.prefix(4))
    }
}

// MARK: - Language options grown from the day (pure, deterministic)

/// "What direction suits learning right now" — derived from where you are and
/// how the day moves, NOT asked of the model (deterministic, testable). Each
/// option becomes the theme fed into the vocab picker.
enum LanguageScenarios {

    static func options(nearby: [PlaceKind],
                        activity: Activity?,
                        hour: Int) -> [String] {
        var out: [String] = []
        let near = Set(nearby)
        if !near.isDisjoint(with: [.restaurant, .market, .cafe]) {
            out.append("点餐与食物")
        }
        if activity == .transit || activity == .walking {
            out.append("出行与问路")
        }
        if !near.isDisjoint(with: [.library, .museum]) {
            out.append("阅读与展览")
        }
        if (18...23).contains(hour) || (0..<6).contains(hour) {
            out.append("日常寒暄")
        } else if (6..<11).contains(hour) {
            out.append("早晨的问候")
        }
        if out.isEmpty { out.append("日常寒暄") }
        return Array(out.prefix(3))
    }
}
