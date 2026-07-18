//
//  BookScanView.swift
//  Luminous — 扫书: the shelf of scanned books.
//
//  Scan a new book (Apple's document scanner) → name it → its first page becomes
//  the cover, pages saved upright as entries (BookStore). Tap a book to open the
//  split reader (BookReaderView): the page on top, tap-to-explain words below.
//  Rough cut — a useful travel tool; deeper study in WORD-STUDY-PLAN.md.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct BookScanView: View {
    @Environment(\.theme) private var theme

    @State private var books: [Book] = []
    @State private var showScanner = false
    @State private var pending: [Data] = []       // scanned pages awaiting a name
    @State private var showNaming = false
    @State private var draftName = ""
    @State private var openBook: Book?
    @State private var editing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("扫一本书，之后一页一页读、一个词一个词认。")
                        .font(.system(size: 13)).lineSpacing(3)
                        .foregroundStyle(theme.textSecondary)
                    scanButton
                    if books.isEmpty {
                        Text("书架还空着。扫一本书放上来。")
                            .font(.system(size: 13)).foregroundStyle(theme.textMuted).padding(.top, 4)
                    } else {
                        shelf
                    }
                }
                .padding(Spacing.lg)
            }
            .themedScreen()
            .navigationTitle("扫书")
            .inlineNavTitle()
            .toolbar {
                if !books.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button(editing ? "完成" : "整理") { editing.toggle() }
                            .foregroundStyle(theme.accentText)
                    }
                }
            }
            .navigationDestination(item: $openBook) { book in
                BookReaderView(book: book)
            }
        }
        .onAppear(perform: reload)
        #if canImport(VisionKit) && os(iOS)
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScanner(
                onFinish: { images in
                    showScanner = false
                    let data = images.compactMap { $0.jpegData(compressionQuality: 0.9) }
                    if !data.isEmpty {
                        pending = data
                        draftName = "第 \(books.count + 1) 本书"
                        showNaming = true
                    }
                },
                onCancel: { showScanner = false })
            .ignoresSafeArea()
        }
        #endif
        .alert("给这本书起个名字", isPresented: $showNaming) {
            TextField("书名", text: $draftName)
            Button("存下") {
                let name = draftName.trimmingCharacters(in: .whitespaces)
                BookStore.create(name: name.isEmpty ? "第 \(books.count + 1) 本书" : name, pages: pending)
                pending = []; reload()
            }
            Button("取消", role: .cancel) { pending = [] }
        } message: {
            Text("第一页会成为它的封面。")
        }
    }

    // MARK: scan entry

    @ViewBuilder private var scanButton: some View {
        #if canImport(VisionKit) && os(iOS)
        if DocumentScanner.isSupported {
            Button { showScanner = true } label: { scanLabel }
                .buttonStyle(.plain)
        } else { unavailable }
        #else
        unavailable
        #endif
    }

    private var scanLabel: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.viewfinder").font(.system(size: 22, weight: .light))
            VStack(alignment: .leading, spacing: 2) {
                Text("扫一本新书").font(.system(size: 16, weight: .medium))
                Text("翻页就好 — 拍清楚了它自己会拍下来")
                    .font(.system(size: 12)).foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
        .foregroundStyle(theme.accentText)
        .padding(Spacing.md).frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var unavailable: some View {
        Text("扫描需要在 iPhone / iPad 上用相机。")
            .font(.system(size: 13)).foregroundStyle(theme.textMuted)
            .padding(Spacing.md).frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceSoft).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: the shelf

    private var shelf: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: Spacing.md)],
                  alignment: .leading, spacing: Spacing.md) {
            ForEach(books) { book in bookCell(book) }
        }
    }

    @ViewBuilder private func bookCell(_ book: Book) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                if !editing { openBook = book }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    cover(book)
                    Text(book.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.textPrimary).lineLimit(1)
                    Text("\(book.pageCount) 页")
                        .font(.system(size: 11)).foregroundStyle(theme.textMuted)
                }
            }
            .buttonStyle(.plain)
            if editing {
                Button { BookStore.delete(book.id); reload() } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20)).symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                }
                .buttonStyle(.plain).padding(5)
                .accessibilityLabel("删除这本书")
            }
        }
    }

    @ViewBuilder private func cover(_ book: Book) -> some View {
        if let url = book.cover, let data = BookStore.data(for: url), let img = platformImage(data) {
            img.resizable().scaledToFill()
                .frame(height: 150).frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(theme.border, lineWidth: 1))
        } else {
            RoundedRectangle(cornerRadius: 12).fill(theme.surfaceSoft).frame(height: 150)
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

    private func reload() { books = BookStore.books() }
}
