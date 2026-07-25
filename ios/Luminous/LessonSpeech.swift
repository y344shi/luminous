//
//  LessonSpeech.swift
//  Luminous — read a generated lesson aloud, in the right voice per line.
//
//  A lesson is mixed: 中文 explanation, the book's own language (e.g. French)
//  for words and examples, and some English. Reading it all with one voice makes
//  the French sound wrong, so we split it into lines and give each the voice it
//  needs. The book's foreign language can be pinned in Settings (BookPrefs
//  .lessonLanguage) — detection on a two-word fragment is unreliable, so an
//  explicit choice wins.
//

import Foundation
import NaturalLanguage

enum LessonSpeech {

    /// Split a Markdown lesson into speakable segments, each tagged with a language.
    static func segments(for markdown: String, foreignLanguage: String? = nil)
    -> [(text: String, language: String?)] {
        let forced = (foreignLanguage?.isEmpty == false)
            ? foreignLanguage
            : (BookPrefs.lessonLanguage.isEmpty ? nil : BookPrefs.lessonLanguage)

        var out: [(text: String, language: String?)] = []
        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = clean(rawLine)
            guard !line.isEmpty else { continue }
            out.append((line, language(of: line, forced: forced)))
        }
        return out
    }

    /// Strip Markdown decoration so the voice doesn't read "hash hash star".
    private static func clean(_ s: String) -> String {
        var t = s
        // headings, bullets, quotes, table pipes
        t = t.replacingOccurrences(of: "^\\s*#{1,6}\\s*", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "^\\s*[-*+]\\s+", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "^\\s*>\\s*", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "^\\s*\\|", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\|", with: "，", options: .regularExpression)
        // emphasis + code + links
        t = t.replacingOccurrences(of: "[*_`]{1,3}", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\[([^\\]]*)\\]\\([^\\)]*\\)", with: "$1", options: .regularExpression)
        // separators
        t = t.replacingOccurrences(of: "^\\s*[-–—=]{3,}\\s*$", with: "", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Chinese lines are read in 中文; everything else uses the pinned language
    /// when there is one (detection is unreliable on short fragments), else the
    /// detector's best guess.
    private static func language(of line: String, forced: String?) -> String? {
        if hasCJK(line) { return "zh-CN" }
        if let forced, !forced.isEmpty {
            // A clearly-English sentence still reads better in English.
            if line.count >= 25, detect(line) == "en" { return "en-US" }
            return forced
        }
        return detect(line)
    }

    private static func hasCJK(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x4E00...0x9FFF).contains(Int($0.value)) }
    }

    private static func detect(_ s: String) -> String? {
        let r = NLLanguageRecognizer(); r.processString(s)
        return r.dominantLanguage?.rawValue
    }
}
