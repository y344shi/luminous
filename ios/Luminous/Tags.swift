//
//  Tags.swift
//  Luminous — small soft labels a wish can wear (never a taxonomy to maintain)
//
//  Pure and Foundation-only (in the SwiftPM test package). Suggestions come
//  from what the wish already is (its categories, its detected topics, a few
//  title keywords); the user edits freely. The rules live here: normalized,
//  deduped, ForbiddenWords-filtered, and never more than MAX per wish.
//

import Foundation

// MARK: - Topic detection (single source of truth; used by tags, learning, store)

enum LearningTopic {
    /// The language a wish is about, as a Chinese label — or nil if it isn't a
    /// language-learning wish. Mirrors the web app's keyword parse.
    static func language(ofTitle raw: String) -> String? {
        let t = raw.lowercased()
        if raw.contains("法语") || raw.contains("法文") || t.contains("french") { return "法语" }
        if raw.contains("英语") || raw.contains("英文") || t.contains("english") { return "英语" }
        if raw.contains("日语") || raw.contains("日文") || t.contains("japanese") { return "日语" }
        if raw.contains("西班牙") || t.contains("spanish") { return "西班牙语" }
        if raw.contains("德语") || raw.contains("德文") || t.contains("german") { return "德语" }
        if raw.contains("韩语") || raw.contains("韩文") || t.contains("korean") { return "韩语" }
        if raw.contains("意大利") || t.contains("italian") { return "意大利语" }
        return nil
    }

    /// Is this seed a learning pursuit at all (language wish, or learning category)?
    static func isLearning(_ seed: Seed) -> Bool {
        language(ofTitle: seed.title) != nil || seed.categories.contains(.learning)
    }

    /// Map a detected source-language name (English, as the OCR/LLM returns it) to
    /// the Chinese label the learning pursuits use, so a translated photo lands in
    /// the right anchor's history. Unknown names pass through unchanged.
    static func label(forEnglishLanguage name: String) -> String {
        switch name.lowercased() {
        case let n where n.contains("french"):   return "法语"
        case let n where n.contains("english"):  return "英语"
        case let n where n.contains("japanese"): return "日语"
        case let n where n.contains("spanish"):  return "西班牙语"
        case let n where n.contains("german"):   return "德语"
        case let n where n.contains("korean"):   return "韩语"
        case let n where n.contains("italian"):  return "意大利语"
        case let n where n.contains("chinese"):  return "中文"
        default: return name.isEmpty ? "未知" : name
        }
    }
}

enum TagSuggest {

    /// The hard cap — a wish wears at most five tags.
    static let maxTags = 5

    /// The card's FIXED facets — category / duration / energy already live as
    /// uneditable chips above. User tags are alternatives to these dimensions,
    /// never duplicates of them.
    static let reserved: Set<String> = {
        var r = Set(SeedCategory.allCases.compactMap { Meta.category[$0]?.label })
        r.formUnion(Meta.energyLabel.values)
        r.formUnion(["几分钟", "十几分钟", "半小时内", "一小时内", "可长可短"])
        return r
    }()

    /// Clean one raw tag: trims, strips a leading #, caps length, refuses
    /// forbidden vocabulary and the card's fixed facets. Returns nil when
    /// nothing worth keeping remains.
    static func clean(_ raw: String) -> String? {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while t.hasPrefix("#") { t.removeFirst() }
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, ForbiddenWords.passes(t), !reserved.contains(t) else { return nil }
        return String(t.prefix(10))
    }

    /// Merge candidate lists into one clean, deduped, capped tag set —
    /// earlier lists win slots first (user's own before suggestions).
    static func merge(_ lists: [String]...) -> [String] {
        var out: [String] = []
        for list in lists {
            for raw in list {
                guard let t = clean(raw), !out.contains(t) else { continue }
                out.append(t)
                if out.count == maxTags { return out }
            }
        }
        return out
    }

    private static let keywordTags: [(pattern: String, tag: String)] = [
        ("读|看书|book|阅读", "阅读"),
        ("走|散步|跑|walk|run", "走动"),
        ("歌|音乐|music|听", "音乐"),
        ("写|画|draw|write", "创作"),
        ("朋友|妈|爸|家人|friend", "身边的人"),
        ("水|茶|咖啡", "喝点什么"),
        ("睡|休息|躺", "休息"),
    ]

    /// Suggestions grown from what the wish already is — TOPIC tags only
    /// (language, 下厨, title keywords). Category/duration/energy stay on the
    /// card's fixed chips and are never offered here.
    static func suggest(title: String, categories: [SeedCategory]) -> [String] {
        var out: [String] = []
        if let lang = LearningTopic.language(ofTitle: title) { out.append(lang) }
        if WishTopics.isCooking(title) { out.append("下厨") }
        for (pattern, tag) in keywordTags where title.range(of: pattern, options: .regularExpression) != nil {
            if !out.contains(tag) { out.append(tag) }
        }
        return Array(out.prefix(6))   // offer a bit more than the cap; user chooses
    }
}
