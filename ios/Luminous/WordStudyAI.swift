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

/// One step of a little language lesson: a word/phrase from the page, explained
/// in English and 中文. Played as a voice-over (word in its language, then the
/// explanations) to teach how each word is used.
struct LessonStep: Codable, Hashable {
    var word: String        // the original-language word/phrase
    var english: String     // how it's used + meaning, in English
    var chinese: String     // 中文 解释
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
            let instructions = PromptTemplates.instructions(.word)
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
            let instructions = PromptTemplates.instructions(.notes)
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

    /// A little lesson over the whole page: walk the key words/phrases in order,
    /// each with how it's used + its meaning (English + 中文). nil when the model
    /// is away.
    static func lesson(for text: String) async -> [LessonStep]? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), AIHelper.isAvailable {
            let instructions = PromptTemplates.instructions(.lesson)
            if let r = try? await LanguageModelSession(instructions: instructions)
                .respond(to: "这一页的原文：「\(t.prefix(600))」", generating: GenLesson.self) {
                let steps = r.content.steps
                    .filter { !$0.word.trimmingCharacters(in: .whitespaces).isEmpty
                              && ForbiddenWords.passes($0.english + $0.chinese) }
                    .map { LessonStep(word: $0.word, english: $0.english, chinese: $0.chinese) }
                return steps.isEmpty ? nil : steps
            }
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenLessonStep {
    @Guide(description: "原文里的一个词或短语，保持原来的语言")
    var word: String
    @Guide(description: "一句英文，讲这个词的意思和用法")
    var english: String
    @Guide(description: "一句简体中文，讲这个词的意思和用法")
    var chinese: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenLesson {
    @Guide(description: "按原文顺序，为主要的词和短语各做一步讲解")
    var steps: [GenLessonStep]
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenPageNotes {
    @Guide(description: "三条学习笔记，每条都包含原文里的一个词或短语，再加它的英文解释和简体中文解释", .count(3))
    var notes: [String]
}
#endif
