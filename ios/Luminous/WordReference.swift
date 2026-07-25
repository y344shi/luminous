//
//  WordReference.swift
//  Luminous — a real dictionary reference + example sentence per word.
//
//  Complements the model's explanation with authoritative sources, when online:
//   • definition / phonetic from the free Dictionary API (best for English), and
//   • a real example sentence WITH translation from Tatoeba (great for French).
//  Both are best-effort and degrade to nil offline. The genuine "Oxford" entry is
//  Apple's on-device dictionary (Oxford-Hachette French / Oxford Dictionary of
//  English) — surfaced natively elsewhere; this is the inline, online reference.
//

import Foundation

struct WordRef: Hashable {
    var phonetic: String?
    var partOfSpeech: String?
    var definition: String?
    var exampleText: String?         // in the word's own language
    var exampleTranslation: String?  // English

    var isEmpty: Bool {
        (definition ?? "").isEmpty && (exampleText ?? "").isEmpty
    }
}

enum WordReference {
    /// ISO-639-1 → Tatoeba's ISO-639-3 code (for example sentences).
    private static let tatoeba: [String: String] = [
        "fr": "fra", "en": "eng", "es": "spa", "de": "deu", "it": "ita",
        "pt": "por", "ja": "jpn", "zh": "cmn", "ru": "rus", "nl": "nld", "ko": "kor",
    ]

    /// Look a word up: definition (Dictionary API) + one example (Tatoeba). Runs
    /// both in parallel; returns nil only when both come back empty.
    static func look(_ word: String, language: String?) async -> WordRef? {
        let w = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !w.isEmpty else { return nil }
        let lang2 = (language ?? "en").lowercased().prefix(2).description

        async let def = definition(w, lang: lang2)
        async let ex = example(w, lang: lang2)
        var ref = WordRef()
        if let d = await def { ref.phonetic = d.phonetic; ref.partOfSpeech = d.pos; ref.definition = d.def }
        if let e = await ex { ref.exampleText = e.text; ref.exampleTranslation = e.translation }
        return ref.isEmpty ? nil : ref
    }

    // MARK: sources

    private static func definition(_ word: String, lang: String) async -> (phonetic: String?, pos: String?, def: String)? {
        guard let enc = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/\(lang)/\(enc)") else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(from: url),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = arr.first else { return nil }
        let phonetic = (first["phonetic"] as? String)
            ?? (first["phonetics"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.first
        guard let meanings = first["meanings"] as? [[String: Any]], let m = meanings.first,
              let defs = m["definitions"] as? [[String: Any]],
              let d = defs.first?["definition"] as? String else { return nil }
        return (phonetic, m["partOfSpeech"] as? String, d)
    }

    private static func example(_ word: String, lang: String) async -> (text: String, translation: String)? {
        guard let from = tatoeba[lang],
              let enc = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://tatoeba.org/en/api_v0/search?from=\(from)&to=eng&query=\(enc)&sort=relevance")
        else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(from: url),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = obj["results"] as? [[String: Any]] else { return nil }
        // Prefer a real sentence (more than the bare word) that has an English translation.
        for r in results {
            guard let text = r["text"] as? String, text.count > word.count + 2 else { continue }
            let en = englishTranslation(in: r["translations"])
            if let en { return (text, en) }
        }
        // Otherwise the first result with any translation.
        for r in results {
            guard let text = r["text"] as? String else { continue }
            if let en = englishTranslation(in: r["translations"]) { return (text, en) }
        }
        return nil
    }

    /// Tatoeba nests translations as an array of arrays of {lang, text}.
    private static func englishTranslation(in any: Any?) -> String? {
        guard let groups = any as? [[[String: Any]]] else {
            if let flat = any as? [[String: Any]] {
                return flat.first { ($0["lang"] as? String) == "eng" }?["text"] as? String
            }
            return nil
        }
        for group in groups {
            if let t = group.first(where: { ($0["lang"] as? String) == "eng" })?["text"] as? String { return t }
        }
        return nil
    }
}
