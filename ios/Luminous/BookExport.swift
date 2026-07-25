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

    /// The book's foreign language, for reading lessons aloud. "" = auto-detect.
    /// Setting it (e.g. "fr") guarantees the非中文 parts are spoken with that
    /// language's voice, instead of relying on detection of short fragments.
    private static let langKey = "tdd.book.lessonLanguage"
    static var lessonLanguage: String {
        get { UserDefaults.standard.string(forKey: langKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: langKey) }
    }

    /// The languages offered in Settings (code, label).
    static let lessonLanguageOptions: [(code: String, label: String)] = [
        ("", "自动识别"), ("fr", "法语"), ("en", "英语"), ("es", "西班牙语"),
        ("de", "德语"), ("it", "意大利语"), ("ja", "日语"), ("ko", "韩语"),
    ]
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

    /// Why a lesson couldn't be made — so the UI can say something actionable
    /// instead of a guess.
    enum LessonOutcome {
        case ok(String)
        case failed(reason: String)
    }

    /// A complete "understand this whole book" lesson: all vocabulary in batch, then
    /// the grammar foundations the book uses. Built through the gateway (cloud), and
    /// cached so it isn't regenerated. Returns Markdown, or nil when unreachable.
    static func fullBookLesson(_ book: Book, force: Bool = false,
                               progress: (@Sendable (Int, Int) -> Void)? = nil) async -> String? {
        if case .ok(let s) = await fullBookLessonOutcome(book, force: force, progress: progress) { return s }
        return nil
    }

    static func fullBookLessonOutcome(_ book: Book, force: Bool = false,
                                      progress: (@Sendable (Int, Int) -> Void)? = nil) async -> LessonOutcome {
        if !force, let cached = cachedLesson(book) { return .ok(cached) }
        let docs = await transcribe(book, progress: progress)
        guard !docs.isEmpty else { return .failed(reason: "这本书还没认出文字。") }

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

        // Cloud (gateway) first, unless we're in local-only mode. A full-book
        // lesson is a big generation — give it minutes, not the default 60s, or
        // it times out mid-think and returns nothing.
        var cloudTried = false
        if CloudLLM.isConfigured {
            cloudTried = true
            if let out = await CloudLLM.chat(system: sys, user: user, maxTokens: 8000, timeout: 900),
               !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cache(out, book: book)
                return .ok(out)
            }
        }

        // On-device (Apple Intelligence). The local model's context window is a
        // fraction of the cloud's, so it gets a COMPACT brief — the whole-book
        // prompt above would overflow it and fail even when the model is ready.
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            guard AIHelper.isAvailable else {
                return .failed(reason: localUnavailableMessage(cloudTried: cloudTried))
            }
            let topVocab = ranked.prefix(60).map { "\($0.word)(\($0.count))" }.joined(separator: "、")
            let brief = """
            这是一本\(lang)图画书里的词和句子。请用简体中文写一份简明的课（Markdown）：
            1) 常用词：按下面的顺序（出现最多的在前）讲解，每个给出词性、英文意思、中文意思。
            2) 语法基础：这些句子用到的主要语法点，各配一个书里的例句。
            常用词：\(topVocab)
            书里的句子（节选）：
            \(text.prefix(1200))
            """
            if let r = try? await LanguageModelSession(instructions: sys).respond(to: brief) {
                let out = r.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !out.isEmpty { cache(out, book: book); return .ok(out) }
            }
            return .failed(reason: cloudTried
                ? "云端没连上，本机模型这次也没写出来（书比较长时会这样）。可以先导出 XML/JSON 交给 ChatGPT，再把课粘回来。"
                : "本机模型这次没写出来。可以先导出 XML/JSON 交给 ChatGPT，再把课粘回来。")
        }
        #endif
        return .failed(reason: localUnavailableMessage(cloudTried: cloudTried))
    }

    /// A precise, actionable reason (uses the system's own explanation).
    private static func localUnavailableMessage(cloudTried: Bool) -> String {
        let why = AIHelper.unavailableReason
        let local = why.isEmpty ? "本机模型暂时不可用" : why
        return cloudTried
            ? "云端没连上（在外面时家里的地址访问不到），本机也不行：\(local)。可以先导出 XML/JSON 交给 ChatGPT，再把课粘回来。"
            : "\(local)。可以先导出 XML/JSON 交给 ChatGPT，再把课粘回来。"
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
    /// Save a lesson the user brought in (e.g. pasted from ChatGPT) with the book.
    static func saveLesson(_ s: String, book: Book) {
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
