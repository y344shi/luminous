//
//  BookReaderView.swift
//  Luminous — 逐字读: read a scanned book, page by page, word by word.
//
//  A split reader: the top pane shows the scanned page (swipe page by page),
//  a draggable handle resizes it, and the bottom pane shows that page's
//  paragraph as clickable word tokens — no explanations up front. Tap a word
//  and its meaning fills a region in the lower half (English + 中文 + 语法 /
//  用法 / 例句, on-device). Next: tap groups a meaningful phrase, and tapping an
//  already-highlighted region subdivides it (WORD-STUDY-PLAN.md).
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct BookReaderView: View {
    let book: Book
    @Environment(\.theme) private var theme

    @State private var pageIndex = 0
    @State private var split: CGFloat = 0.52      // top-pane height fraction
    @State private var baseSplit: CGFloat = 0.52
    @State private var tokensByPage: [Int: [[String]]] = [:]
    @State private var selected: String?
    @State private var cards: [String: WordCard] = [:]

    private var pages: [URL] { book.pageURLs }

    var body: some View {
        GeometryReader { geo in
            let H = geo.size.height
            let topH = max(150, min(H - 200, H * split))
            VStack(spacing: 0) {
                pagePane.frame(height: topH)
                divider(totalHeight: H)
                bottomPane.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .themedScreen()
        .navigationTitle(book.name)
        .inlineNavTitle()
        .task(id: pageIndex) { await loadTokens(pageIndex) }
    }

    // MARK: top — the page, swipeable

    private var pagePane: some View {
        #if os(iOS)
        TabView(selection: $pageIndex) {
            ForEach(Array(pages.enumerated()), id: \.offset) { i, url in
                pageImage(url).tag(i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .background(theme.surfaceSoft)
        #else
        VStack(spacing: 8) {
            pageImage(pages[min(pageIndex, pages.count - 1)])
            HStack {
                Button("‹") { if pageIndex > 0 { pageIndex -= 1 } }
                Text("\(pageIndex + 1) / \(pages.count)").font(.system(size: 12))
                Button("›") { if pageIndex < pages.count - 1 { pageIndex += 1 } }
            }.padding(.bottom, 6)
        }
        .background(theme.surfaceSoft)
        #endif
    }

    private func pageImage(_ url: URL) -> some View {
        Group {
            if let data = BookStore.data(for: url), let img = platformImage(data) {
                img.resizable().scaledToFit()
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(6)
    }

    // MARK: the draggable handle

    private func divider(totalHeight H: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(theme.surface)
            Capsule().fill(theme.textMuted.opacity(0.5)).frame(width: 42, height: 5)
        }
        .frame(height: 22).frame(maxWidth: .infinity)
        .overlay(Rectangle().fill(theme.border.opacity(0.5)).frame(height: 1), alignment: .top)
        .overlay(Rectangle().fill(theme.border.opacity(0.5)).frame(height: 1), alignment: .bottom)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { v in
                    split = min(0.82, max(0.2, baseSplit + v.translation.height / max(H, 1)))
                }
                .onEnded { _ in baseSplit = split }
        )
        .accessibilityLabel("拖动调整上下比例")
    }

    // MARK: bottom — the paragraph as tappable words + the explanation region

    private var bottomPane: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    let lines = tokensByPage[pageIndex]
                    if lines == nil {
                        HStack(spacing: 10) { ProgressView(); Text("正在读这一页…")
                            .font(.system(size: 13)).foregroundStyle(theme.textSecondary) }
                    } else if lines?.isEmpty == true {
                        Text("这一页没认出文字。")
                            .font(.system(size: 13)).foregroundStyle(theme.textMuted)
                    } else {
                        ForEach(Array((lines ?? []).enumerated()), id: \.offset) { _, line in
                            FlowLayout(spacing: 5) {
                                ForEach(Array(line.enumerated()), id: \.offset) { _, token in
                                    wordChip(token)
                                }
                            }
                        }
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let selected {
                explanation(for: selected)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(theme.background)
    }

    private func wordChip(_ token: String) -> some View {
        let key = Self.clean(token)
        let isSel = selected == key
        return Button {
            guard !key.isEmpty else { return }
            withAnimation(.easeOut(duration: 0.2)) { selected = key }
            if cards[key] == nil { Task { await explain(key) } }
        } label: {
            Text(token)
                .font(.system(size: 19)).lineSpacing(4)
                .foregroundStyle(isSel ? theme.accentText : theme.textPrimary)
                .padding(.horizontal, 3).padding(.vertical, 1)
                .background(isSel ? theme.accentSoft : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .disabled(key.isEmpty)
    }

    // The explanation region — the lower part of the "later half".
    @ViewBuilder private func explanation(for word: String) -> some View {
        let card = cards[word]
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(word).font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button { withAnimation(.easeOut(duration: 0.2)) { selected = nil } } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18)).foregroundStyle(theme.textMuted.opacity(0.7))
                }.buttonStyle(.plain).accessibilityLabel("收起")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if let card {
                        row("English", card.english)
                        row("中文", card.chinese)
                        row("语法", card.grammar)
                        row("用法", card.usage)
                        row("例句", card.example)
                    } else if WordStudy.isAvailable {
                        HStack(spacing: 10) { ProgressView(); Text("正在想…")
                            .font(.system(size: 14)).foregroundStyle(theme.textSecondary) }
                    } else {
                        Text("这个词的解释需要本机的语言模型（真机上、开启 Apple Intelligence 时）。现在先记住它的样子。")
                            .font(.system(size: 14)).lineSpacing(4).foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .overlay(Rectangle().fill(theme.border.opacity(0.6)).frame(height: 1), alignment: .top)
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(theme.textMuted)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 16)).lineSpacing(3).foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: work

    private func loadTokens(_ page: Int) async {
        guard page < pages.count, tokensByPage[page] == nil else { return }
        let text = await BookStore.ocrText(for: pages[page])
        var rows: [[String]] = []
        for rawLine in text.split(separator: "\n") {
            let words = rawLine.split(separator: " ").map(String.init)
            if !words.isEmpty { rows.append(words) }
        }
        await MainActor.run { tokensByPage[page] = rows }
    }

    private func explain(_ word: String) async {
        let context = (tokensByPage[pageIndex] ?? [])
            .first(where: { $0.map(Self.clean).contains(word) })?
            .joined(separator: " ") ?? word
        if let card = await WordStudy.base(for: word, context: context) {
            await MainActor.run { cards[word] = card }
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

    private static func clean(_ token: String) -> String {
        token.trimmingCharacters(in: CharacterSet.alphanumerics.inverted
            .subtracting(CharacterSet(charactersIn: "'’-")))
            .trimmingCharacters(in: CharacterSet(charactersIn: "'’-"))
    }
}
