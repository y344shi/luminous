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
/// in English and 中文, plus a teaching note that connects it to the rest of the
/// sentence. Played as a voice-over (word in its language, then the meaning, then
/// the note) to teach how each word is used and how it links to the others.
struct LessonStep: Codable, Hashable {
    var word: String        // the original-language word/phrase
    var english: String     // meaning, in English
    var chinese: String     // 中文 意思
    // The richer part — how the word works and connects to its neighbours
    // (grammar, agreement, what it points to / pairs with). Bilingual. Optional
    // so older cached lessons (without it) still decode.
    var note: String?
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

/// Cloud JSON shapes (the OpenAI-compatible equivalents of the @Generable structs).
private struct CloudWord: Codable { var english, chinese, grammar, usage, example: String }
private struct CloudNotes: Codable { var notes: [String] }
private struct CloudLessonStepJSON: Codable { var word, english, chinese: String; var note: String? }
private struct CloudLessonJSON: Codable { var steps: [CloudLessonStepJSON] }

enum WordStudy {
    /// Available when the on-device model is up OR a cloud endpoint is configured.
    static var isAvailable: Bool { AIHelper.isAvailable || CloudLLM.isConfigured }

    /// Explain `word` as it appears in `context` (its sentence). Returns nil when
    /// the model is unavailable or the output can't pass the forbidden-words gate.
    static func base(for word: String, context: String,
                     instructions: String = PromptTemplates.instructions(.word)) async -> WordCard? {
        let w = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !w.isEmpty else { return nil }

        // Cloud endpoint (your H200 etc.) first, when configured.
        if CloudLLM.isConfigured {
            let user = """
            在这句话里：「\(context.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))」
            解释其中的这个词：「\(w)」。
            返回 JSON：{"english": 基本英文释义, "chinese": 基本中文释义, "grammar": 词性/语法, "usage": 用法, "example": 一个带中文意思的例句}
            """
            if let c: CloudWord = await CloudLLM.json(system: instructions, user: user, as: CloudWord.self),
               ForbiddenWords.passes([c.english, c.chinese, c.grammar, c.usage, c.example].joined(separator: " ")) {
                return WordCard(word: w, english: c.english, chinese: c.chinese,
                                grammar: c.grammar, usage: c.usage, example: c.example)
            }
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), AIHelper.isAvailable {
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
    static func notes(for text: String,
                      instructions: String = PromptTemplates.instructions(.notes)) async -> [String]? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }

        if CloudLLM.isConfigured {
            let user = """
            这一页的原文：「\(t.prefix(600))」
            返回 JSON：{"notes": [三条学习笔记，每条都含原文里的一个词或短语，再加它的英文解释和简体中文解释]}
            """
            if let c: CloudNotes = await CloudLLM.json(system: instructions, user: user, as: CloudNotes.self) {
                let notes = c.notes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && ForbiddenWords.passes($0) }
                if !notes.isEmpty { return notes }
            }
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), AIHelper.isAvailable {
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
    static func lesson(for text: String,
                       instructions: String = PromptTemplates.instructions(.lesson)) async -> [LessonStep]? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }

        if CloudLLM.isConfigured {
            let user = """
            这一页的原文：「\(t.prefix(600))」
            按原文顺序为主要的词和短语各做一步讲解。每一步除了意思，还要讲清楚它在这句话里怎么用、\
            以及它和前后词的关系（比如性数配合、和哪个词搭配、指向谁、时态语气）。
            返回 JSON：{"steps": [{"word": 原文里的词或短语, "english": 一句英文意思, "chinese": 一句简体中文意思, "note": 两三句话的讲解，说明它的语法作用和它怎样和句子里其它词连起来，中英文都可以}]}
            """
            if let c: CloudLessonJSON = await CloudLLM.json(system: instructions, user: user, as: CloudLessonJSON.self, maxTokens: 3200) {
                let steps = c.steps
                    .filter { !$0.word.trimmingCharacters(in: .whitespaces).isEmpty
                              && ForbiddenWords.passes($0.english + $0.chinese + " " + ($0.note ?? "")) }
                    .map { LessonStep(word: $0.word, english: $0.english, chinese: $0.chinese,
                                      note: ($0.note?.isEmpty == false) ? $0.note : nil) }
                if !steps.isEmpty { return steps }
            }
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), AIHelper.isAvailable {
            if let r = try? await LanguageModelSession(instructions: instructions)
                .respond(to: "这一页的原文：「\(t.prefix(600))」", generating: GenLesson.self) {
                let steps = r.content.steps
                    .filter { !$0.word.trimmingCharacters(in: .whitespaces).isEmpty
                              && ForbiddenWords.passes($0.english + $0.chinese + " " + $0.note) }
                    .map { LessonStep(word: $0.word, english: $0.english, chinese: $0.chinese,
                                      note: $0.note.isEmpty ? nil : $0.note) }
                return steps.isEmpty ? nil : steps
            }
        }
        #endif
        return nil
    }

    /// "再讲深一点" — expand on something already generated. Takes what the learner
    /// has already been told and asks for MORE: the parts that were skipped,
    /// nuance, contrast with near-synonyms, extra examples. Cloud first (it has
    /// the room), on-device fallback with a shorter brief. nil when neither works.
    static func deepen(topic: String, sofar: String, context: String = "",
                       language: String? = nil) async -> String? {
        let t = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let lang = (language?.isEmpty == false) ? "（原文语言代码：\(language!)）" : ""
        let sys = """
        你是一位耐心的语言老师。学习者已经看过下面的讲解，现在想更深入。\
        不要重复已经说过的内容，只补充新的：更细的用法差别、容易混淆的近义表达、\
        变化形式、地道例句（都带中文意思）、以及为什么这样说。用简体中文，Markdown 分点。
        """
        let user = """
        要深入讲解的对象：「\(t)」\(lang)
        \(context.isEmpty ? "" : "它出现的上下文：「\(context.prefix(300))」")
        学习者已经看过的讲解：
        \(sofar.prefix(2000))

        请补充更多，不要重复上面已有的内容。
        """

        if CloudLLM.isConfigured,
           let out = await CloudLLM.chat(system: sys, user: user, maxTokens: 2000, timeout: 240),
           !out.isEmpty, ForbiddenWords.passes(out) {
            return out
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), AIHelper.isAvailable {
            // The on-device model needs a much shorter brief to fit its window.
            let brief = """
            再深入讲讲「\(t)」\(lang)：用法差别、近义表达、变化形式、两个地道例句（带中文意思）。\
            不要重复这些：\(sofar.prefix(400))
            """
            if let r = try? await LanguageModelSession(instructions: sys).respond(to: brief) {
                let out = r.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !out.isEmpty, ForbiddenWords.passes(out) { return out }
            }
        }
        #endif
        return nil
    }

    /// Run one generation with a GIVEN prompt on a sample sentence, ignoring the
    /// cache — so the prompt editor's "试一下" can show what a prompt actually does.
    /// Returns a readable multi-line string, or nil when no model produced output.
    static func preview(kind: PromptKind, instructions: String, sample: String) async -> String? {
        let s = sample.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        switch kind {
        case .word:
            // Explain the longest word in the sample, in the sample's context.
            let word = s.split { !$0.isLetter && $0 != "'" && $0 != "’" }
                .map(String.init).max(by: { $0.count < $1.count }) ?? s
            guard let c = await base(for: word, context: s, instructions: instructions) else { return nil }
            return "【\(c.word)】\nEnglish: \(c.english)\n中文: \(c.chinese)\n语法: \(c.grammar)\n用法: \(c.usage)\n例句: \(c.example)"
        case .notes:
            guard let n = await notes(for: s, instructions: instructions), !n.isEmpty else { return nil }
            return n.map { "• \($0)" }.joined(separator: "\n")
        case .lesson:
            guard let l = await lesson(for: s, instructions: instructions), !l.isEmpty else { return nil }
            return l.map { step in
                var t = "▸ \(step.word)\n   EN: \(step.english)\n   中: \(step.chinese)"
                if let n = step.note, !n.isEmpty { t += "\n   ↳ \(n)" }
                return t
            }.joined(separator: "\n\n")
        }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenLessonStep {
    @Guide(description: "原文里的一个词或短语，保持原来的语言")
    var word: String
    @Guide(description: "一句英文意思")
    var english: String
    @Guide(description: "一句简体中文意思")
    var chinese: String
    @Guide(description: "两三句话的讲解：这个词在句中的语法作用，以及它怎样和前后的词连起来（性数配合、搭配、指向、时态语气）。中英文都可以")
    var note: String
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
