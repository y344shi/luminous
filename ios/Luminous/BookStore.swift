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
}

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
}
#endif
