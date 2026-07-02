//
//  SuggestAI.swift
//  Luminous — the model phrases the moment; the code decides what's allowed
//
//  Two voices, both strictly bounded:
//  • Reason-writer: rephrases a chosen opportunity's reason in the app's tone.
//    The WHAT was already decided by the scorer — the model only touches HOW
//    it's said. Late-night reasons are never touched (that copy is safety copy).
//  • Moment suggester: proposes up to 3 tiny context-born suggestions to ride
//    the shooting stars. Closed category set, ForbiddenWords, length caps;
//    the static Suggester pool remains the floor and the fallback.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenReason {
    @Guide(description: "一两句话，温柔地说明为什么此刻刚好适合做这件小事。不催促、不评判、不夸张。")
    var reason: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenMoment {
    @Guide(description: "一个 emoji")
    var emoji: String
    @Guide(description: "很短的标题，8 个字以内")
    var title: String
    @Guide(description: "小到现在就能做完的一步，20 个字以内")
    var action: String
    @Guide(description: "类别，只能从这些里选：body, creation, connection, exploration, recovery, learning, aesthetic")
    var category: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenMoments {
    @Guide(description: "恰好三个此刻合适的小事", .count(3))
    var moments: [GenMoment]
}
#endif

enum SuggestAI {

    /// Rephrase a reason in the app's voice. Returns nil (keep the template)
    /// on any doubt. NEVER called for late-night contexts — that copy is a
    /// safety message and stays code-owned.
    static func rewriteReason(seedTitle: String, action: String,
                              template: String, contextLine: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), AIHelper.isAvailable {
            let instructions = """
            你替一个温柔的生活锚点应用说话。把给出的理由换一种更贴近此刻的说法，\
            一两句话。不命令、不催促、不诊断、没有截止日期式的语言。
            """
            let prompt = """
            愿望：「\(seedTitle)」，最小的一步：「\(action)」。
            此刻：\(contextLine)。
            原本的理由：「\(template)」。
            """
            guard let r = try? await LanguageModelSession(instructions: instructions)
                .respond(to: prompt, generating: GenReason.self) else { return nil }
            let text = r.content.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, text.count <= 60, ForbiddenWords.passes(text) else { return nil }
            return text
        }
        #endif
        return nil
    }

    /// Up to 3 context-born moment suggestions in the app's voice. The caller
    /// must gate on !isLateNight; invalid categories/words are dropped here.
    static func moments(contextLine: String) async -> [Suggestion] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), AIHelper.isAvailable {
            let instructions = """
            你替一个温柔的生活锚点应用想「此刻刚好能做的小事」。每件事都要小、\
            具体、五分钟内能开始。不是待办，没有必须。
            """
            let prompt = "此刻：\(contextLine)。请想恰好三件。"
            guard let r = try? await LanguageModelSession(instructions: instructions)
                .respond(to: prompt, generating: GenMoments.self) else { return [] }
            return r.content.moments.compactMap { m in
                guard let cat = SeedCategory(rawValue: m.category) else { return nil }
                let title = String(m.title.prefix(10))
                let action = String(m.action.prefix(24))
                guard !title.isEmpty, !action.isEmpty,
                      ForbiddenWords.passes(title + action) else { return nil }
                return Suggestion(id: "ai_\(title)", emoji: String(m.emoji.prefix(2)),
                                  title: title, action: action, category: cat)
            }
        }
        #endif
        return []
    }
}
