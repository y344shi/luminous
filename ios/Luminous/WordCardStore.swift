//
//  WordCardStore.swift
//  Luminous — a per-book glossary cache, so tapping a word is instant.
//
//  Explaining a word takes a model round-trip (seconds on-device, longer over the
//  network). While you're reading a page you're very likely to tap several of its
//  words, so we explain them AHEAD of time, in the background, and keep the
//  results with the book. A word explained on page 3 is instant on page 7, and
//  the glossary travels with the book (it's included in the XML/JSON export).
//
//  Stored as `Books/<id>/wordcards.json`. MainActor so views can read it
//  synchronously while drawing.
//

import Foundation

@MainActor
enum WordCardStore {
    /// bookID → (lowercased word → card)
    private static var memory: [String: [String: WordCard]] = [:]
    /// Books whose page is currently being pre-warmed, so we don't stack passes.
    private static var warming: Set<String> = []

    private static func url(_ bookID: String) -> URL {
        BookStore.root.appendingPathComponent(bookID, isDirectory: true)
            .appendingPathComponent("wordcards.json")
    }

    /// Every cached card for a book (loads from disk once).
    static func all(_ bookID: String) -> [String: WordCard] {
        if let m = memory[bookID] { return m }
        let loaded = (try? Data(contentsOf: url(bookID)))
            .flatMap { try? JSONDecoder().decode([String: WordCard].self, from: $0) } ?? [:]
        memory[bookID] = loaded
        return loaded
    }

    /// An already-explained word, or nil. Instant.
    static func card(_ word: String, book bookID: String) -> WordCard? {
        all(bookID)[key(word)]
    }

    static func put(_ card: WordCard, book bookID: String) {
        var m = all(bookID)
        m[key(card.word)] = card
        memory[bookID] = m
        persist(bookID)
    }

    private static func persist(_ bookID: String) {
        guard let m = memory[bookID],
              let data = try? JSONEncoder().encode(m) else { return }
        try? data.write(to: url(bookID), options: .atomic)
    }

    static func key(_ w: String) -> String {
        w.trimmingCharacters(in: CharacterSet.alphanumerics.inverted
            .subtracting(CharacterSet(charactersIn: "'’-")))
         .trimmingCharacters(in: CharacterSet(charactersIn: "'’-"))
         .lowercased()
    }

    // MARK: pre-warming

    /// Explain the words of a page in the background, skipping ones already known.
    /// Sequential and capped — this is a courtesy pass, not a stampede; it must
    /// never compete with what the reader asked for directly.
    static func prewarm(pageURL: URL, book bookID: String, limit: Int = 40) {
        let token = "\(bookID)|\(pageURL.lastPathComponent)"
        guard !warming.contains(token) else { return }
        warming.insert(token)

        Task {
            defer { warming.remove(token) }
            let text = await BookStore.ocrText(for: pageURL)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

            // Unique words in reading order, with the sentence each sits in.
            var seen = Set<String>()
            var work: [(word: String, context: String)] = []
            for line in text.components(separatedBy: .newlines) {
                for raw in line.split(separator: " ") {
                    let w = String(raw)
                    let k = key(w)
                    guard k.count >= 2, !seen.contains(k) else { continue }
                    seen.insert(k)
                    if card(k, book: bookID) != nil { continue }   // already known
                    work.append((w, line))
                    if work.count >= limit { break }
                }
                if work.count >= limit { break }
            }
            guard !work.isEmpty else { return }

            for item in work {
                if Task.isCancelled { return }
                // Someone may have explained it while we worked.
                if card(item.word, book: bookID) != nil { continue }
                if let c = await WordStudy.base(for: item.word, context: item.context) {
                    put(c, book: bookID)
                }
            }
        }
    }
}
