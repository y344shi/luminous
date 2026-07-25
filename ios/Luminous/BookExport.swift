//
//  BookExport.swift
//  Luminous — turn a scanned book into a portable study document.
//
//  Transcribe every page (OCR text + identified words, all cached), then either:
//   • export a page-by-page XML / JSON annotation document you can hand to any AI
//     (e.g. ChatGPT) to build a full lesson from, or
//   • generate that lesson in-app through our cloud model (the gateway).
//
//  The words per page carry their boxes, so the whole book is captured as an
//  annotatable, dialogue-structured document — external, not the internal
//  .luminousbook archive.
//

import Foundation
import NaturalLanguage
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Whether books get transcribed for export / study, remembered across launches.
/// A Settings toggle sets it; a first-time pop-up offers it.
enum BookPrefs {
    private static let enabledKey = "tdd.book.transcribe"
    private static let askedKey = "tdd.book.transcribeAsked"

    static var transcribeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
    static var hasAsked: Bool {
        get { UserDefaults.standard.bool(forKey: askedKey) }
        set { UserDefaults.standard.set(newValue, forKey: askedKey) }
    }
}

/// One transcribed page.
struct BookPageDoc {
    let index: Int
    let text: String
    let words: [WordBox]
    let en: String?
    let zh: String?
}

enum BookExportFormat { case xml, json }

enum BookExport {

    // MARK: transcription

    /// OCR every page (cached) and gather its text + identified words. This IS the
    /// "transcription" both the export and the full-book lesson depend on.
    static func transcribe(_ book: Book, progress: (@Sendable (Int, Int) -> Void)? = nil) async -> [BookPageDoc] {
        var docs: [BookPageDoc] = []
        let total = book.pageURLs.count
        for (i, url) in book.pageURLs.enumerated() {
            let text = await BookStore.ocrText(for: url)
            let boxes = await BookStore.wordBoxes(for: url)
            let t = BookStore.cachedTranslation(for: url)
            docs.append(BookPageDoc(index: i + 1, text: text, words: boxes, en: t?.english, zh: t?.chinese))
            progress?(i + 1, total)
        }
        return docs
    }

    static func language(of docs: [BookPageDoc]) -> String {
        let all = docs.map(\.text).joined(separator: " ")
        guard !all.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "und" }
        let r = NLLanguageRecognizer(); r.processString(all)
        return r.dominantLanguage?.rawValue ?? "und"
    }

    /// Vocabulary across the whole book, ranked by how often each word appears
    /// (most frequent first; ties keep first-seen order).
    static func vocabularyRanked(_ docs: [BookPageDoc]) -> [(word: String, count: Int)] {
        var counts: [String: Int] = [:], disp: [String: String] = [:], firstIdx: [String: Int] = [:]
        var n = 0
        for d in docs {
            for w in d.words {
                let k = clean(w.text)
                guard !k.isEmpty else { continue }
                let key = k.lowercased()
                if counts[key] == nil { firstIdx[key] = n; n += 1; disp[key] = k }
                counts[key, default: 0] += 1
            }
        }
        return counts.keys
            .map { (word: disp[$0] ?? $0, count: counts[$0] ?? 0, idx: firstIdx[$0] ?? 0) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.idx < $1.idx }
            .map { (word: $0.word, count: $0.count) }
    }

    /// Just the words, frequency-ordered.
    static func vocabulary(_ docs: [BookPageDoc]) -> [String] {
        vocabularyRanked(docs).map(\.word)
    }

    // MARK: document export (external)

    static func export(_ book: Book, as format: BookExportFormat,
                       progress: (@Sendable (Int, Int) -> Void)? = nil) async -> URL? {
        let docs = await transcribe(book, progress: progress)
        switch format {
        case .xml:  return writeXML(book, docs)
        case .json: return writeJSON(book, docs)
        }
    }

    private static func writeXML(_ book: Book, _ docs: [BookPageDoc]) -> URL? {
        let lang = language(of: docs)
        var s = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!-- Luminous book export — a page-by-page, word-level annotation document.
             Suggested ask to an AI: "Teach me this whole book. First explain EVERY
             vocabulary word in batch (original, part of speech, English + 中文 meaning,
             a short example). Then explain, from the foundations, all the grammar the
             book uses, with example sentences taken from the book — so that being able
             to understand the book is the reward." -->
        <book title="\(esc(book.name))" language="\(lang)" pages="\(docs.count)" exportedBy="Luminous">

        """
        for d in docs {
            s += "  <page index=\"\(d.index)\">\n"
            s += "    <text>\(esc(d.text))</text>\n"
            s += "    <words>\n"
            for w in d.words where !w.text.trimmingCharacters(in: .whitespaces).isEmpty {
                s += "      <w x=\"\(fmt(w.x))\" y=\"\(fmt(w.y))\" w=\"\(fmt(w.w))\" h=\"\(fmt(w.h))\">\(esc(w.text))</w>\n"
            }
            s += "    </words>\n"
            if let en = d.en { s += "    <translation lang=\"en\">\(esc(en))</translation>\n" }
            if let zh = d.zh { s += "    <translation lang=\"zh\">\(esc(zh))</translation>\n" }
            s += "  </page>\n"
        }
        s += "</book>\n"
        return write(Data(s.utf8), name: book.name, ext: "xml")
    }

    private static func writeJSON(_ book: Book, _ docs: [BookPageDoc]) -> URL? {
        let lang = language(of: docs)
        var obj: [String: Any] = [
            "title": book.name, "language": lang, "pageCount": docs.count, "exportedBy": "Luminous",
            "instructions": "Teach this whole book. First explain EVERY vocabulary word in batch (original, part of speech, English + 中文 meaning, a short example). Then explain, from the foundations, all the grammar the book uses, with example sentences from the book — so that understanding the book is the reward.",
        ]
        obj["pages"] = docs.map { d -> [String: Any] in
            var p: [String: Any] = [
                "index": d.index, "text": d.text,
                "words": d.words.map { ["t": $0.text, "x": $0.x, "y": $0.y, "w": $0.w, "h": $0.h] },
            ]
            if d.en != nil || d.zh != nil {
                var tr: [String: String] = [:]
                if let en = d.en { tr["en"] = en }
                if let zh = d.zh { tr["zh"] = zh }
                p["translation"] = tr
            }
            return p
        }
        guard let data = try? JSONSerialization.data(
            withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else { return nil }
        return write(data, name: book.name, ext: "json")
    }

    // MARK: full-book lesson (in-app, via our cloud model)

    /// A complete "understand this whole book" lesson: all vocabulary in batch, then
    /// the grammar foundations the book uses. Built through the gateway (cloud), and
    /// cached so it isn't regenerated. Returns Markdown, or nil when unreachable.
    static func fullBookLesson(_ book: Book, force: Bool = false,
                               progress: (@Sendable (Int, Int) -> Void)? = nil) async -> String? {
        if !force, let cached = cachedLesson(book) { return cached }
        let docs = await transcribe(book, progress: progress)
        guard !docs.isEmpty else { return nil }

        let lang = language(of: docs)
        let ranked = vocabularyRanked(docs)
        let vocabLine = ranked.prefix(400).map { "\($0.word)(\($0.count))" }.joined(separator: "、")
        let text = docs.map { "第\($0.index)页：\($0.text)" }.joined(separator: "\n")
        let sys = "你是一位耐心细致的语言老师。用简体中文讲解，目标是帮学习者读懂并学会整本书。"
        let user = """
        这是一整本图画书（语言代码：\(lang)）。请写一份完整的“读懂这本书”的课，用清晰的 Markdown（标题、列表）：
        1) 词汇（批量，按出现频率从高到低）：把书里出现的词都讲一遍，先讲最常出现的。每个词给出：原文、出现次数、词性、英文意思、简体中文意思，必要时一个例子。
        2) 语法基础：把这本书用到的语法点从最基础讲清楚（冠词与性数配合、动词变位与时态、代词、介词、句子结构等），每一点都用书里的原句作例子。
        3) 收尾：想读懂这本书，最关键要掌握的几点。
        全书原文：
        \(text.prefix(6000))

        书里识别到的词（已按频率排序，括号是次数）：\(vocabLine)
        """

        // Cloud (gateway) first, unless we're in local-only mode.
        if CloudLLM.isConfigured,
           let out = await CloudLLM.chat(system: sys, user: user, maxTokens: 4000),
           !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cache(out, book: book)
            return out
        }

        // On-device (Apple Intelligence) — the local AI can build it too.
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), AIHelper.isAvailable,
           let r = try? await LanguageModelSession(instructions: sys).respond(to: user) {
            let out = r.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !out.isEmpty { cache(out, book: book); return out }
        }
        #endif

        return cachedLesson(book)
    }

    static func cachedLesson(_ book: Book) -> String? {
        try? String(contentsOf: lessonURL(book), encoding: .utf8)
    }
    static func lessonMarkdownURL(_ book: Book) -> URL? {
        cachedLesson(book) == nil ? nil : lessonURL(book)
    }
    private static func cache(_ s: String, book: Book) {
        try? s.write(to: lessonURL(book), atomically: true, encoding: .utf8)
    }
    private static func lessonURL(_ book: Book) -> URL {
        BookStore.root.appendingPathComponent(book.id, isDirectory: true)
            .appendingPathComponent("lesson-full.md")
    }

    // MARK: helpers

    private static func clean(_ s: String) -> String {
        s.trimmingCharacters(in: CharacterSet.alphanumerics.inverted
            .subtracting(CharacterSet(charactersIn: "'’-")))
         .trimmingCharacters(in: CharacterSet(charactersIn: "'’-"))
    }
    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
    private static func fmt(_ d: Double) -> String { String(format: "%.4f", d) }

    private static func write(_ data: Data, name: String, ext: String) -> URL? {
        let safe = name.isEmpty ? "book" : name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe).\(ext)")
        do { try data.write(to: url); return url } catch { return nil }
    }
}
