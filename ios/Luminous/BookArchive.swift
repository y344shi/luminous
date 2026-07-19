//
//  BookArchive.swift
//  Luminous — 扫书: a shareable, self-contained book file (.luminousbook).
//
//  A whole book — its pages, hand annotations, and the OCR / translation / notes
//  caches — packed into ONE Codable file so it can travel between devices over
//  AirDrop (ShareLink out, .fileImporter in). No zip library, no document-type
//  registration: a binary property list holds the page image data and the
//  annotation drawings directly. Round-trips losslessly; annotations come along.
//
//  File layout (the "shareable file structure for annotation"):
//    BookArchive { name, createdAt, pages: [ArchivedPage] }
//    ArchivedPage { image, annotation?, annotationPNG?, ocr?, english?, chinese?, notes? }
//

import Foundation

struct ArchivedPage: Codable {
    var image: Data                 // the page JPEG (upright)
    var annotation: Data?           // PKDrawing.dataRepresentation()
    var annotationPNG: Data?        // rendered transparent overlay
    var ocr: String?
    var english: String?
    var chinese: String?
    var notes: [String]?
}

struct BookArchive: Codable {
    static let fileExtension = "luminousbook"
    static let currentVersion = 1

    var version: Int = currentVersion
    var name: String
    var createdAt: Date
    var pages: [ArchivedPage]

    // MARK: export

    /// Pack a book into a single file in the temp dir; returns its URL for sharing.
    static func export(_ book: Book) -> URL? {
        var pages: [ArchivedPage] = []
        for url in book.pageURLs {
            guard let image = BookStore.data(for: url) else { continue }
            let base = url.deletingPathExtension()
            pages.append(ArchivedPage(
                image: image,
                annotation: BookStore.annotation(for: url),
                annotationPNG: BookStore.annotationPNG(for: url),
                ocr: sidecarString(base, "txt"),
                english: sidecarTranslation(base)?.english,
                chinese: sidecarTranslation(base)?.chinese,
                notes: sidecarNotes(base)))
        }
        let archive = BookArchive(name: book.name, createdAt: book.createdAt, pages: pages)
        let encoder = PropertyListEncoder(); encoder.outputFormat = .binary
        guard let data = try? encoder.encode(archive) else { return nil }
        let safe = book.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(safe.isEmpty ? "book" : safe)
            .appendingPathExtension(fileExtension)
        try? FileManager.default.removeItem(at: url)
        return (try? data.write(to: url)) != nil ? url : nil
    }

    // MARK: import

    /// Unpack a received .luminousbook into a new book on disk. Returns it.
    @discardableResult
    static func importArchive(from fileURL: URL) -> Book? {
        // Security-scoped for files handed in by the document picker.
        let scoped = fileURL.startAccessingSecurityScopedResource()
        defer { if scoped { fileURL.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: fileURL),
              let archive = try? PropertyListDecoder().decode(BookArchive.self, from: data)
        else { return nil }

        let id = "book-\(Int(archive.createdAt.timeIntervalSince1970))-\(UUID().uuidString.prefix(4))"
        let dir = BookStore.root.appendingPathComponent(id, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        writeMeta(id: id, name: archive.name, createdAt: archive.createdAt, to: dir)

        for (i, page) in archive.pages.enumerated() {
            let base = dir.appendingPathComponent(String(format: "page-%04d", i))
            try? page.image.write(to: base.appendingPathExtension("jpg"))
            if let a = page.annotation { try? a.write(to: base.appendingPathExtension("ann")) }
            if let p = page.annotationPNG { try? p.write(to: base.appendingPathExtension("annpng")) }
            if let t = page.ocr { try? t.write(to: base.appendingPathExtension("txt"), atomically: true, encoding: .utf8) }
            if let en = page.english, let zh = page.chinese,
               let d = try? JSONEncoder().encode(SidecarTranslation(english: en, chinese: zh)) {
                try? d.write(to: base.appendingPathExtension("trans"))
            }
            if let notes = page.notes, let d = try? JSONEncoder().encode(notes) {
                try? d.write(to: base.appendingPathExtension("notes"))
            }
        }
        return BookStore.book(id: id)
    }

    // MARK: helpers (read the sidecars written by BookStore)

    private struct SidecarTranslation: Codable { var english: String; var chinese: String }

    private static func sidecarString(_ base: URL, _ ext: String) -> String? {
        try? String(contentsOf: base.appendingPathExtension(ext), encoding: .utf8)
    }
    private static func sidecarTranslation(_ base: URL) -> SidecarTranslation? {
        guard let d = try? Data(contentsOf: base.appendingPathExtension("trans")) else { return nil }
        return try? JSONDecoder().decode(SidecarTranslation.self, from: d)
    }
    private static func sidecarNotes(_ base: URL) -> [String]? {
        guard let d = try? Data(contentsOf: base.appendingPathExtension("notes")) else { return nil }
        return try? JSONDecoder().decode([String].self, from: d)
    }
    private static func writeMeta(id: String, name: String, createdAt: Date, to dir: URL) {
        struct Meta: Codable { var id: String; var name: String; var createdAt: Date }
        if let d = try? JSONEncoder().encode(Meta(id: id, name: name, createdAt: createdAt)) {
            try? d.write(to: dir.appendingPathComponent("meta.json"))
        }
    }
}
