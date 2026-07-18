//
//  WordStudyAI.swift
//  Luminous — 逐字读: the on-device model explains one word.
//
//  Phase A of WORD-STUDY-PLAN.md: the BASE card only — a word's basic meaning in
//  English + 简体中文, plus part-of-speech/grammar, usage, and one example. Any
//  source language (auto-detected, like 拍照翻译). Later phases add the two-axis
//  deepening (breadth ↓ / depth →), dwell-adaptive length, persistence, and
//  review. House pattern: @Generable structured output + a graceful nil fallback
//  (the reader shows a gentle note when the model is away — always in the
//  Simulator) + ForbiddenWords on everything shown.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// The base explanation of one word — a plain value so it persists/caches easily.
struct WordCard: Codable, Hashable {
    var word: String
    var english: String
    var chinese: String
    var grammar: String
    var usage: String
    var example: String
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenWordCard {
    @Guide(description: "the word's basic meaning in natural English — a few words, not a sentence")
    var english: String
    @Guide(description: "the word's basic meaning in Simplified Chinese — 几个字")
    var chinese: String
    @Guide(description: "part of speech and one key grammar note, in Simplified Chinese, one short line")
    var grammar: String
    @Guide(description: "how this word is typically used, in Simplified Chinese, one sentence")
    var usage: String
    @Guide(description: "one short example in the original language, followed by its 简体中文 meaning")
    var example: String
}
#endif

enum WordStudy {
    /// Shares availability with the rest of the on-device AI.
    static var isAvailable: Bool { AIHelper.isAvailable }

    /// Explain `word` as it appears in `context` (its sentence). Returns nil when
    /// the model is unavailable or the output can't pass the forbidden-words gate.
    static func base(for word: String, context: String) async -> WordCard? {
        let w = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !w.isEmpty else { return nil }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), AIHelper.isAvailable {
            let instructions = """
            你在帮一个人读一本外语书。原文可能是任何语言，先认出这个词是什么语言。\
            给出这个词最基本的意思，简洁、准确：英文和简体中文各一个基本释义，\
            再加词性/语法、用法、一个带中文意思的例句。只解释这个词本身，\
            不要评论，不要鼓励或催促的话。
            """
            let prompt = """
            在这句话里：「\(context.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))」
            解释其中的这个词：「\(w)」
            """
            if let r = try? await LanguageModelSession(instructions: instructions)
                .respond(to: prompt, generating: GenWordCard.self) {
                let c = r.content
                let blob = [c.english, c.chinese, c.grammar, c.usage, c.example].joined(separator: " ")
                if ForbiddenWords.passes(blob) {
                    return WordCard(word: w, english: c.english, chinese: c.chinese,
                                    grammar: c.grammar, usage: c.usage, example: c.example)
                }
            }
        }
        #endif
        return nil
    }

    /// A few short, interesting reading notes for a whole page — so you can read
    /// it without tapping every word. nil when the model is away.
    static func notes(for text: String) async -> [String]? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), AIHelper.isAvailable {
            let instructions = """
            你在帮一个人读一本外语书。给这一页挑几条简短、有趣、实用的读书笔记（简体中文，\
            每条一句）：最有用或最有意思的词、搭配、语法或文化点，让他不用逐词查也能快速读懂、\
            学到东西。不要评论，不要鼓励或催促的话。
            """
            if let r = try? await LanguageModelSession(instructions: instructions)
                .respond(to: "这一页的原文：「\(t.prefix(600))」", generating: GenPageNotes.self) {
                let notes = r.content.notes
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && ForbiddenWords.passes($0) }
                return notes.isEmpty ? nil : notes
            }
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenPageNotes {
    @Guide(description: "三条简短有趣的读书笔记，简体中文，每条一句", .count(3))
    var notes: [String]
}
#endif
