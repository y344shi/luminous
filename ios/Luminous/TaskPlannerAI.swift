//
//  TaskPlannerAI.swift
//  Luminous — the model breaks a wish into tiny steps with real resources
//
//  App targets only. The LLM proposes; PlanKit validates; the deterministic
//  fallback plan means the card is never empty-handed. Plans are cached per
//  seed for the session (transient — a plan is for this moment, not forever).
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenPlanStep {
    @Guide(description: "很小的一步，24 个字以内，现在就能开始，不是作业")
    var title: String
    @Guide(description: "这一步用得上的资源，只能从这些里选：route（找个合适的地点）, vocab（学几个词）, photo（拍照翻译）, breath（先呼吸）, none（不需要资源）")
    var resource: String
    @Guide(description: "资源的主题提示（比如词的方向、地点的类型），16 字以内，可为空")
    var detail: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenPlan {
    @Guide(description: "把愿望拆成的 2 到 4 小步，从最容易的开始", .count(3))
    var steps: [GenPlanStep]
}
#endif

enum TaskPlanner {

    /// Break a wish into tiny steps. LLM proposes → PlanKit validates →
    /// deterministic fallback. Always returns a usable plan.
    static func plan(for seed: Seed, contextLine: String) async -> [PlanStep] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), AIHelper.isAvailable {
            let instructions = """
            你帮一个温柔的生活锚点应用把一个愿望拆成很小的几步。每一步都要小到\
            现在就能开始，语气是邀请，不是布置。如果某一步真的用得上一个资源\
            （找个地点 route / 学几个词 vocab / 拍照翻译 photo / 先呼吸 breath），\
            就标出来；不需要就写 none。不要编造资源。
            """
            let prompt = """
            愿望：「\(seed.title)」，它的最小动作：「\(seed.minimumAction)」。
            此刻：\(contextLine)。
            请拆成三小步，从最容易的开始。
            """
            if let r = try? await LanguageModelSession(instructions: instructions)
                .respond(to: prompt, generating: GenPlan.self),
               let valid = PlanKit.validate(r.content.steps.map {
                   ($0.title, $0.resource, $0.detail)
               }) {
                return valid
            }
        }
        #endif
        return PlanKit.fallback(for: seed)
    }
}
