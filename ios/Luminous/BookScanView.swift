//
//  BookScanView.swift
//  Luminous — 扫书: the tab. Flip through a book, it captures each page by
//  itself (Apple's document scanner), and the pages collect here so you can
//  translate / study them later (tap a page → 拍照翻译). Minimal on purpose;
//  the deep word-by-word study card is a separate, richer surface (see
//  WORD-STUDY-PLAN.md). Rough first cut — a useful travel tool.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct BookScanView: View {
    @Environment(\.theme) private var theme

    @State private var pages: [URL] = []
    @State private var showScanner = false
    @State private var translatePage: PageRef?
    @State private var editing = false

    /// A page to hand to 拍照翻译 (image data + a stable id for the sheet).
    private struct PageRef: Identifiable { let id: URL; let data: Data }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("一页一页翻，它会自己拍清楚。之后再慢慢读、慢慢译。")
                        .font(.system(size: 13)).lineSpacing(3)
                        .foregroundStyle(theme.textSecondary)

                    scanButton

                    if pages.isEmpty {
                        Text("还没有扫过页。翻开一本书，按上面开始。")
                            .font(.system(size: 13)).foregroundStyle(theme.textMuted)
                            .padding(.top, 4)
                    } else {
                        grid
                    }
                }
                .padding(Spacing.lg)
            }
            .themedScreen()
            .navigationTitle("扫书")
            .inlineNavTitle()
            .toolbar {
                if !pages.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button(editing ? "完成" : "整理") { editing.toggle() }
                            .foregroundStyle(theme.accentText)
                    }
                }
            }
        }
        .onAppear(perform: reload)
        #if canImport(VisionKit) && os(iOS)
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScanner(
                onFinish: { images in
                    showScanner = false
                    ScannedPagesStore.save(images, sessionStamp: Int(Date().timeIntervalSince1970))
                    reload()
                },
                onCancel: { showScanner = false })
            .ignoresSafeArea()
        }
        #endif
        .sheet(item: $translatePage) { page in
            TranslateView(initialImageData: page.data)
            #if os(iOS)
                .presentationBackground(.regularMaterial)
            #else
                .frame(minWidth: 420, minHeight: 560)
            #endif
        }
    }

    // MARK: scan entry

    @ViewBuilder private var scanButton: some View {
        #if canImport(VisionKit) && os(iOS)
        if DocumentScanner.isSupported {
            Button { showScanner = true } label: { scanLabel }
                .buttonStyle(.plain)
        } else {
            unavailable
        }
        #else
        unavailable
        #endif
    }

    private var scanLabel: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.viewfinder").font(.system(size: 22, weight: .light))
            VStack(alignment: .leading, spacing: 2) {
                Text("扫这本书").font(.system(size: 16, weight: .medium))
                Text("翻页就好 — 拍清楚了它自己会拍下来")
                    .font(.system(size: 12)).foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
        .foregroundStyle(theme.accentText)
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var unavailable: some View {
        Text("扫描需要在 iPhone / iPad 上用相机。")
            .font(.system(size: 13)).foregroundStyle(theme.textMuted)
            .padding(Spacing.md).frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceSoft)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: the captured pages

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: Spacing.sm)],
                  spacing: Spacing.sm) {
            ForEach(pages, id: \.self) { url in pageCell(url) }
        }
    }

    @ViewBuilder private func pageCell(_ url: URL) -> some View {
        ZStack(alignment: .topTrailing) {
            if let data = ScannedPagesStore.data(for: url), let image = platformImage(data) {
                image
                    .resizable().scaledToFill()
                    .frame(height: 150).frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !editing { translatePage = PageRef(id: url, data: data) }
                    }
            } else {
                RoundedRectangle(cornerRadius: 12).fill(theme.surfaceSoft).frame(height: 150)
            }
            if editing {
                Button { ScannedPagesStore.delete(url); reload() } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                }
                .buttonStyle(.plain)
                .padding(5)
                .accessibilityLabel("删除这一页")
            }
        }
    }

    private func platformImage(_ data: Data) -> Image? {
        #if canImport(UIKit)
        return UIImage(data: data).map { Image(uiImage: $0) }
        #elseif canImport(AppKit)
        return NSImage(data: data).map { Image(nsImage: $0) }
        #else
        return nil
        #endif
    }

    private func reload() { pages = ScannedPagesStore.pages() }
}
