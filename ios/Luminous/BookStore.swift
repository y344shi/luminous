//
//  BookStore.swift
//  Luminous — 扫书: scanned books on disk.
//
//  A book is a folder under Documents/Books/<id>/ : a meta.json (name, date) +
//  page-000.jpg, page-001.jpg … (upright, in order) + a page-000.txt OCR cache
//  written the first time a page is read. The first page is the book's cover.
//  Everything stays on the device.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct Book: Identifiable, Hashable {
    let id: String
    var name: String
    var createdAt: Date
    var pageURLs: [URL]
    var cover: URL? { pageURLs.first }
    var pageCount: Int { pageURLs.count }
}

private struct BookMeta: Codable { var id: String; var name: String; var createdAt: Date }

enum BookStore {
    static var root: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Books", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Every book, newest first.
    static func books() -> [Book] {
        let dirs = (try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil)) ?? []
        return dirs.compactMap(book(fromDir:)).sorted { $0.createdAt > $1.createdAt }
    }

    static func book(id: String) -> Book? {
        book(fromDir: root.appendingPathComponent(id, isDirectory: true))
    }

    private static func book(fromDir dir: URL) -> Book? {
        guard let data = try? Data(contentsOf: dir.appendingPathComponent("meta.json")),
              let meta = try? JSONDecoder().decode(BookMeta.self, from: data) else { return nil }
        return Book(id: meta.id, name: meta.name, createdAt: meta.createdAt,
                    pageURLs: pageURLs(in: dir))
    }

    private static func pageURLs(in dir: URL) -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)) ?? []
        return items.filter { $0.pathExtension.lowercased() == "jpg" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Create a new book from a scan session (JPEG data per page); the first
    /// page is the cover.
    @discardableResult
    static func create(name: String, pages: [Data]) -> Book? {
        let id = "book-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(4))"
        let dir = root.appendingPathComponent(id, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let meta = BookMeta(id: id, name: name, createdAt: Date())
        if let data = try? JSONEncoder().encode(meta) {
            try? data.write(to: dir.appendingPathComponent("meta.json"))
        }
        savePages(pages, to: dir, startIndex: 0)
        return book(fromDir: dir)
    }

    /// Append a later scan session to an existing book.
    static func addPages(_ pages: [Data], to bookID: String) {
        let dir = root.appendingPathComponent(bookID, isDirectory: true)
        savePages(pages, to: dir, startIndex: pageURLs(in: dir).count)
    }

    private static func savePages(_ pages: [Data], to dir: URL, startIndex: Int) {
        for (i, data) in pages.enumerated() {
            let out: Data
            #if canImport(UIKit)
            out = UIImage(data: data)?.upright().jpegData(compressionQuality: 0.8) ?? data
            #else
            out = data
            #endif
            let name = String(format: "page-%04d.jpg", startIndex + i)
            try? out.write(to: dir.appendingPathComponent(name))
        }
    }

    static func delete(_ bookID: String) {
        try? FileManager.default.removeItem(at: root.appendingPathComponent(bookID, isDirectory: true))
    }

    static func data(for pageURL: URL) -> Data? { try? Data(contentsOf: pageURL) }

    // MARK: Apple Pencil annotations (per page)

    /// The raw PKDrawing data for a page (editable source), or nil if none.
    static func annotation(for pageURL: URL) -> Data? {
        try? Data(contentsOf: pageURL.deletingPathExtension().appendingPathExtension("ann"))
    }

    /// A rendered transparent PNG of the annotation, for display over the page.
    static func annotationPNG(for pageURL: URL) -> Data? {
        try? Data(contentsOf: pageURL.deletingPathExtension().appendingPathExtension("annpng"))
    }

    /// Save (or clear, when both nil) a page's annotation: the editable drawing
    /// data plus a rendered PNG overlay.
    static func saveAnnotation(_ drawing: Data?, png: Data?, for pageURL: URL) {
        let base = pageURL.deletingPathExtension()
        let annURL = base.appendingPathExtension("ann")
        let pngURL = base.appendingPathExtension("annpng")
        if let drawing { try? drawing.write(to: annURL) } else { try? FileManager.default.removeItem(at: annURL) }
        if let png { try? png.write(to: pngURL) } else { try? FileManager.default.removeItem(at: pngURL) }
    }

    // MARK: rotation (the scanner doesn't always get orientation right)

    /// Rotate one page by `quarterTurns` × 90° clockwise and re-save; clears its
    /// OCR + translation caches (they no longer match).
    static func rotatePage(_ pageURL: URL, quarterTurns: Int) {
        #if canImport(UIKit)
        guard let data = try? Data(contentsOf: pageURL),
              let img = UIImage(data: data),
              let out = img.rotated(quarterTurns: quarterTurns).jpegData(compressionQuality: 0.9)
        else { return }
        try? out.write(to: pageURL)
        clearCaches(for: pageURL)
        #endif
    }

    /// Apply the same rotation to every page of a book (optionally skipping one).
    static func rotateAll(bookID: String, quarterTurns: Int, except: URL? = nil) {
        let dir = root.appendingPathComponent(bookID, isDirectory: true)
        for url in pageURLs(in: dir) where url != except {
            rotatePage(url, quarterTurns: quarterTurns)
        }
    }

    private static func clearCaches(for pageURL: URL) {
        let base = pageURL.deletingPathExtension()
        // A rotated page no longer aligns with its OCR/translation/notes OR its
        // hand annotation, so all of them are cleared.
        for ext in ["txt", "trans", "notes", "ann", "annpng"] {
            try? FileManager.default.removeItem(at: base.appendingPathExtension(ext))
        }
    }

    /// OCR text for a page, cached in a .txt sidecar (read once, reused after).
    static func ocrText(for pageURL: URL) async -> String {
        let sidecar = pageURL.deletingPathExtension().appendingPathExtension("txt")
        if let cached = try? String(contentsOf: sidecar, encoding: .utf8) { return cached }
        guard let data = try? Data(contentsOf: pageURL),
              let (cg, orientation) = ImageInput.load(data),
              let text = try? await VisionOCR.recognize(cg, orientation: orientation) else { return "" }
        try? text.write(to: sidecar, atomically: true, encoding: .utf8)
        return text
    }

    /// The page's EN + 中文 translation, cached in a .trans sidecar. nil when the
    /// model is away (Simulator) or there's no text.
    static func translation(for pageURL: URL) async -> (english: String, chinese: String)? {
        let sidecar = pageURL.deletingPathExtension().appendingPathExtension("trans")
        if let d = try? Data(contentsOf: sidecar),
           let t = try? JSONDecoder().decode(PageTranslation.self, from: d) {
            return (t.english, t.chinese)
        }
        let text = await ocrText(for: pageURL)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let t = try? await Translator.translate(text) else { return nil }
        let pt = PageTranslation(english: t.english, chinese: t.chinese)
        if let d = try? JSONEncoder().encode(pt) { try? d.write(to: sidecar) }
        return (t.english, t.chinese)
    }

    /// A few short reading notes for the page, cached in a .notes sidecar.
    static func notes(for pageURL: URL) async -> [String]? {
        let sidecar = pageURL.deletingPathExtension().appendingPathExtension("notes")
        if let d = try? Data(contentsOf: sidecar),
           let n = try? JSONDecoder().decode([String].self, from: d) { return n }
        let text = await ocrText(for: pageURL)
        guard let n = await WordStudy.notes(for: text), !n.isEmpty else { return nil }
        if let d = try? JSONEncoder().encode(n) { try? d.write(to: sidecar) }
        return n
    }
}

private struct PageTranslation: Codable { var english: String; var chinese: String }

#if canImport(UIKit)
extension UIImage {
    /// Redraw upright so saved pages don't depend on EXIF orientation.
    func upright() -> UIImage {
        if imageOrientation == .up { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Rotate by `quarterTurns` × 90° clockwise, redrawing pixels upright.
    func rotated(quarterTurns: Int) -> UIImage {
        let turns = ((quarterTurns % 4) + 4) % 4
        guard turns != 0 else { return self }
        let up = upright()
        let radians = CGFloat(turns) * .pi / 2
        let newSize = (turns % 2 == 0) ? up.size : CGSize(width: up.size.height, height: up.size.width)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = up.scale
        return UIGraphicsImageRenderer(size: newSize, format: format).image { ctx in
            let c = ctx.cgContext
            c.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            c.rotate(by: radians)
            up.draw(in: CGRect(x: -up.size.width / 2, y: -up.size.height / 2,
                               width: up.size.width, height: up.size.height))
        }
    }
}
#endif
