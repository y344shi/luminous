//
//  DocumentScanner.swift
//  Luminous — 扫书: rapid page capture for a child's picture book.
//
//  Wraps Apple's VisionKit document camera (VNDocumentCameraViewController):
//  it auto-detects the page edges and auto-captures once the view is clear +
//  steady, page after page, so you just keep flipping. Perspective-corrected,
//  multi-page, fully on-device. Captured pages are saved as JPEGs in the app's
//  Documents so you can translate/study them later (拍照翻译). iOS-only; the
//  whole surface is gated to VisionKit + iOS and degrades to nothing elsewhere.
//

import SwiftUI

#if canImport(VisionKit) && os(iOS)
import VisionKit
import UIKit

/// SwiftUI bridge to the system document scanner. `onFinish` gets one image per
/// captured page (in order); `onCancel` fires on cancel or error.
struct DocumentScanner: UIViewControllerRepresentable {
    var onFinish: ([UIImage]) -> Void
    var onCancel: () -> Void

    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner
        init(_ parent: DocumentScanner) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            var pages: [UIImage] = []
            for i in 0..<scan.pageCount { pages.append(scan.imageOfPage(at: i)) }
            parent.onFinish(pages)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            parent.onCancel()
        }
    }
}
#endif

/// Where scanned pages live: JPEGs under Documents/ScannedPages, newest first.
/// Kept dead simple (files, not a DB) — a rough first cut; group into named
/// books later. Nothing leaves the device.
enum ScannedPagesStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("ScannedPages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Every saved page, newest first.
    static func pages() -> [URL] {
        let keys: [URLResourceKey] = [.creationDateKey]
        let items = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys)) ?? []
        return items
            .filter { $0.pathExtension.lowercased() == "jpg" }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return da > db
            }
    }

    #if canImport(UIKit)
    /// Persist a batch of captured pages (one scan session), preserving order.
    static func save(_ images: [UIImage], sessionStamp: Int) {
        for (i, img) in images.enumerated() {
            guard let data = img.jpegData(compressionQuality: 0.8) else { continue }
            let name = String(format: "page-%012d-%03d.jpg", sessionStamp, i)
            try? data.write(to: directory.appendingPathComponent(name))
        }
    }
    #endif

    static func delete(_ url: URL) { try? FileManager.default.removeItem(at: url) }

    static func data(for url: URL) -> Data? { try? Data(contentsOf: url) }
}
