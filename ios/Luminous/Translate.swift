//
//  Translate.swift
//  Luminous — snap a photo, read the text, translate it both ways
//
//  Fully on-device: Vision reads the text off the image (auto-detecting whatever
//  language it's in), then the FoundationModels LLM (iOS 26) renders it into both
//  English and Simplified Chinese. Nothing leaves the phone. Degrades gracefully
//  when the model isn't available (older device / Apple Intelligence off).
//

import Foundation
import Vision
import ImageIO
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Result, framework-independent so the UI never imports FoundationModels

struct Translation: Equatable {
    let sourceLanguage: String
    let english: String
    let chinese: String
}

// MARK: - Load picked bytes → CGImage + EXIF orientation

enum ImageInput {
    /// Decode arbitrary photo/file `Data` into a CGImage plus its stored orientation,
    /// so both OCR and on-screen preview show it the right way up.
    static func load(_ data: Data) -> (image: CGImage, orientation: CGImagePropertyOrientation)? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        var orientation: CGImagePropertyOrientation = .up
        if let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
           let raw = props[kCGImagePropertyOrientation] as? UInt32,
           let o = CGImagePropertyOrientation(rawValue: raw) {
            orientation = o
        }
        return (img, orientation)
    }
}

// MARK: - Vision OCR (any language)

enum VisionOCR {
    enum OCRError: Error { case failed }

    /// Pull every line of text off the image. `automaticallyDetectsLanguage` lets
    /// Vision handle Latin, CJK, and more without us naming the language up front.
    static func recognize(_ cgImage: CGImage,
                          orientation: CGImagePropertyOrientation) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { req, err in
                if let err { cont.resume(throwing: err); return }
                let obs = req.results as? [VNRecognizedTextObservation] ?? []
                let lines = obs.compactMap { $0.topCandidates(1).first?.string }
                cont.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    /// Every recognized WORD with its normalized bounding box (Vision space:
    /// origin bottom-left, 0…1). Used to overlay tappable text on the page.
    static func recognizeWords(_ cgImage: CGImage,
                               orientation: CGImagePropertyOrientation) async throws -> [WordBox] {
        try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { req, err in
                if let err { cont.resume(throwing: err); return }
                let obs = req.results as? [VNRecognizedTextObservation] ?? []
                var out: [WordBox] = []
                for o in obs {
                    guard let cand = o.topCandidates(1).first else { continue }
                    let str = cand.string
                    // Split the line into words and ask Vision for each word's box.
                    var idx = str.startIndex
                    for token in str.split(separator: " ", omittingEmptySubsequences: true) {
                        guard let r = str.range(of: token, range: idx..<str.endIndex) else { continue }
                        idx = r.upperBound
                        if let box = try? cand.boundingBox(for: r), !box.boundingBox.isNull {
                            let b = box.boundingBox
                            out.append(WordBox(text: String(token),
                                               x: b.minX, y: b.minY, w: b.width, h: b.height))
                        }
                    }
                }
                cont.resume(returning: out)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) }
                catch { cont.resume(throwing: error) }
            }
        }
    }
}

/// One recognized word and its normalized box (Vision space, origin bottom-left).
struct WordBox: Codable, Hashable {
    var text: String
    var x: Double; var y: Double; var w: Double; var h: Double
}

// MARK: - Translation via the on-device model

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenTranslation {
    @Guide(description: "the detected source language's name, written in English (e.g. French, Japanese)")
    var sourceLanguage: String
    @Guide(description: "a faithful, natural English translation of the text")
    var english: String
    @Guide(description: "a faithful, natural Simplified Chinese translation of the text")
    var chinese: String
}
#endif

enum Translator {
    /// The model shares availability with the rest of the on-device AI.
    static var isAvailable: Bool { AIHelper.isAvailable }
    static var unavailableReason: String { AIHelper.unavailableReason }

    enum TError: Error { case unavailable, noText }

    /// Translate the OCR'd text into both English and Simplified Chinese, whatever
    /// language it started in. Strategy: try the structured single call first;
    /// if guided generation balks (long text, guardrails, structure sanitization
    /// — the common reasons the 译文 never arrived), fall back to two SIMPLE
    /// unguided calls, which are far more forgiving. Trimmed to stay well inside
    /// the on-device context window.
    static func translate(_ text: String) async throws -> Translation {
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(900))
        guard !trimmed.isEmpty else { throw TError.noText }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            if let t = try? await guided(trimmed) { return t }
            return try await plainTwoStep(trimmed)
        }
        #endif
        throw TError.unavailable
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private static func guided(_ text: String) async throws -> Translation {
        let instructions = """
        你是一个精准的翻译。无论原文是什么语言，都要给出忠实、自然的英文和简体中文翻译。\
        只翻译文字本身，不要添加解释或评论。保留原意与语气。
        """
        let session = LanguageModelSession(instructions: instructions)
        let prompt = """
        识别下面这段文字的语言，然后把它翻译成英文和简体中文：

        \(text)
        """
        let r = try await session.respond(to: prompt, generating: GenTranslation.self)
        guard !r.content.english.isEmpty, !r.content.chinese.isEmpty else { throw TError.noText }
        return Translation(sourceLanguage: r.content.sourceLanguage,
                           english: r.content.english,
                           chinese: r.content.chinese)
    }

    /// The forgiving path: plain text out, one target language per call.
    @available(iOS 26.0, macOS 26.0, *)
    private static func plainTwoStep(_ text: String) async throws -> Translation {
        let instructions = "你是一个精准的翻译。只输出译文本身，不要任何解释、前缀或引号。"
        let en = try await LanguageModelSession(instructions: instructions)
            .respond(to: "把下面这段文字翻译成英文：\n\n\(text)").content
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let zh = try await LanguageModelSession(instructions: instructions)
            .respond(to: "把下面这段文字翻译成简体中文：\n\n\(text)").content
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !en.isEmpty || !zh.isEmpty else { throw TError.noText }
        // language name is a nicety — never let it fail the translation
        let lang = (try? await LanguageModelSession(instructions: "只用一个英文单词回答。")
            .respond(to: "下面这段文字是什么语言？\n\n\(String(text.prefix(120)))").content
            .trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
        return Translation(sourceLanguage: String(lang.prefix(20)),
                           english: en, chinese: zh)
    }
    #endif
}
