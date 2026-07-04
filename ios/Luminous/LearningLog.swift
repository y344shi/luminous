//
//  LearningLog.swift
//  Luminous — learning is a lasting pursuit, not a disposable task
//
//  Language / vocab wishes ("记三个法语单词", "学法语") are treated as a persistent
//  *anchor*: finishing one doesn't throw it away, its history is kept, and a later
//  similar wish merges into it instead of spawning a duplicate. Whether two wishes
//  are "the same pursuit" is judged by the on-device LLM, with a keyword match as a
//  fallback when the model isn't available.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - History

enum LearningKind: String, Codable, Hashable { case vocab, translate }

/// One kept moment of learning — a set of words the AI picked, or a photo we
/// translated. Persisted, and it outlives the seed's completion.
struct LearningEntry: Codable, Identifiable, Hashable {
    var id: String
    var dateKey: String          // YYYY-MM-DD
    var kind: LearningKind
    var language: String         // Chinese label, e.g. 法语 / 日语 / 未知
    var items: [String]          // words, or ["原文 → 译文"] snippets
    var note: String?

    init(kind: LearningKind, language: String, items: [String], note: String? = nil) {
        self.id = DomainUtil.uid("learn")
        self.dateKey = DomainUtil.localDateKey()
        self.kind = kind
        self.language = language
        self.items = items
        self.note = note
    }
}

// LearningTopic (topic detection) moved to Tags.swift — pure Foundation, shared
// with the watch target and the SwiftPM test package.

// MARK: - Merge decision

enum LearningMerge {

    /// Which existing learning pursuit (if any) a new wish continues.
    /// Prefers the on-device LLM; falls back to language/keyword matching.
    /// Returns the id of the seed to merge into, or nil to add fresh.
    static func mergeTarget(newTitle: String,
                            candidates: [(id: String, title: String)]) async -> String? {
        guard !candidates.isEmpty else { return nil }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), AIHelper.isAvailable {
            if let id = await llmChoice(newTitle: newTitle, candidates: candidates) { return id }
        }
        #endif
        return keywordChoice(newTitle: newTitle, candidates: candidates)
    }

    /// Fallback: same detected language → the (already-ordered) first such pursuit.
    /// Otherwise no merge — we stay conservative when unsure.
    static func keywordChoice(newTitle: String,
                              candidates: [(id: String, title: String)]) -> String? {
        if let lang = LearningTopic.language(ofTitle: newTitle) {
            if let hit = candidates.first(where: { LearningTopic.language(ofTitle: $0.title) == lang }) {
                return hit.id
            }
        }
        return nil
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private static func llmChoice(newTitle: String,
                                  candidates: [(id: String, title: String)]) async -> String? {
        let list = candidates.enumerated()
            .map { "\($0.offset + 1). \($0.element.title)" }
            .joined(separator: "\n")
        let instructions = """
        你在帮一个「生活锚点」应用判断：一个新的心愿是不是在延续某个已有的长期心愿\
        （比如同一门语言的学习、同一个持续的练习）。只在明显是同一件长期的事时才合并，\
        否则视为新的。
        """
        let prompt = """
        新的心愿：「\(newTitle)」
        已有的长期心愿：
        \(list)

        如果这个新的心愿是在延续上面某一条，回答它的编号（1 开始）；\
        如果它是全新的、无关的，回答 0。
        """
        do {
            let session = LanguageModelSession(instructions: instructions)
            let r = try await session.respond(to: prompt, generating: GenMergeDecision.self)
            let choice = r.content.choice
            guard choice >= 1, choice <= candidates.count else { return nil }
            return candidates[choice - 1].id
        } catch {
            return nil
        }
    }
    #endif
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenMergeDecision {
    @Guide(description: "the number (1-based) of the existing pursuit this continues, or 0 if it is genuinely new and unrelated")
    var choice: Int
}
#endif
