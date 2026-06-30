//
//  AILesson.swift
//  Luminous — on-device AI that helps *do* a task, not just suggest it
//
//  Uses Apple's on-device model (FoundationModels, iOS 26) — private, free, offline.
//  For an open-ended learning task ("学三个法语单词") it picks the actual content,
//  personalized by what's already been learned + the sensed moment (place / weather /
//  time), so the wish becomes doable on the spot. Degrades gracefully when the model
//  isn't available (older device / Apple Intelligence off).
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// A produced vocabulary item, independent of the model framework so the UI never
/// has to import FoundationModels.
struct VocabItem: Identifiable, Hashable {
    let id = UUID()
    let word: String
    let meaning: String
    let example: String
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenVocabWord {
    @Guide(description: "the word, written in the target language")
    var word: String
    @Guide(description: "its meaning in simplified Chinese")
    var meaning: String
    @Guide(description: "one short, natural example sentence in the target language")
    var example: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenVocabSet {
    @Guide(description: "exactly three new words to learn now", .count(3))
    var words: [GenVocabWord]
}
#endif

enum AIHelper {

    /// Is the on-device model usable right now?
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// A tender, human reason when it isn't.
    static var unavailableReason: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return ""
            case .unavailable(.deviceNotEligible): return "这台设备暂时还用不了端上的智能"
            case .unavailable(.appleIntelligenceNotEnabled): return "在「设置 → Apple 智能」里打开后就能用"
            case .unavailable(.modelNotReady): return "模型还在准备，过一会儿再来"
            case .unavailable: return "端上的智能暂时不可用"
            }
        }
        #endif
        return "需要 iOS 26 和 Apple 智能"
    }

    enum AIError: Error { case unavailable }

    /// Choose three new words to learn, fitting the moment and building on history.
    static func vocab(language: String, learned: [String], context: String) async throws -> [VocabItem] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let instructions = """
            你是一个温柔的语言陪伴者。根据此刻的情境和学习者已经学过的词，\
            挑选少量、贴近当下、用得上的新词。由易到难，循序渐进。不说教、不催促。
            """
            let session = LanguageModelSession(instructions: instructions)
            let learnedStr = learned.isEmpty ? "（还没有）" : learned.joined(separator: "、")
            let prompt = """
            目标语言：\(language)。
            已经学过、请不要重复的词：\(learnedStr)。
            此刻的情境：\(context)。
            请选恰好三个新的、和情境相关、日常能用上的词。
            """
            let r = try await session.respond(to: prompt, generating: GenVocabSet.self)
            return r.content.words.map { VocabItem(word: $0.word, meaning: $0.meaning, example: $0.example) }
        }
        #endif
        throw AIError.unavailable
    }
}
