//
//  BookReaderView.swift
//  Luminous — 逐字读: read a scanned book, page by page, word by word.
//
//  A split reader: the scanned page on top (swipe page by page), a draggable
//  handle to resize, and below — the page's paragraph as clickable words, its
//  EN + 中文 translation shown already (bilingual), and a play button on every
//  sentence / translation / word to hear it in its own language (Siri voice).
//  Tap a word for its meaning (EN + 中文 + 语法/用法/例句, on-device). Pages can
//  be rotated (with apply-to-all) when the scanner got the orientation wrong.
//

import SwiftUI
import NaturalLanguage

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct BookReaderView: View {
    let book: Book
    @Environment(\.theme) private var theme

    @State private var pageIndex = 0
    @State private var split: CGFloat = 0.5
    @State private var baseSplit: CGFloat = 0.5
    @State private var tokensByPage: [Int: [[String]]] = [:]
    @State private var translations: [Int: (en: String, zh: String)] = [:]
    @State private var langByPage: [Int: String] = [:]
    @State private var selected: String?
    @State private var cards: [String: WordCard] = [:]
    @State private var sessionTurns = 0            // rotation applied to this page
    @State private var version = 0                 // bump to reload a rotated page
    @State private var showApplyAll = false
    @State private var speaker = Speaker()

    private var pages: [URL] { book.pageURLs }

    var body: some View {
        GeometryReader { geo in
            let H = geo.size.height
            let topH = max(150, min(H - 220, H * split))
            VStack(spacing: 0) {
                pagePane.frame(height: topH)
                divider(totalHeight: H)
                bottomPane.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .themedScreen()
        .navigationTitle(book.name)
        .inlineNavTitle()
        .toolbar { rotateToolbar }
        .task(id: pageIndex) { await loadPage(pageIndex) }
        .onChange(of: pageIndex) { _, _ in sessionTurns = 0; selected = nil; speaker.stop() }
        .onDisappear { speaker.stop() }
        .alert("整本书都这样转吗？", isPresented: $showApplyAll) {
            Button("好，一起转") {
                BookStore.rotateAll(bookID: book.id, quarterTurns: sessionTurns,
                                    except: pages[safe: pageIndex])
                for i in pages.indices where i != pageIndex {
                    tokensByPage[i] = nil; translations[i] = nil; langByPage[i] = nil
                }
                sessionTurns = 0
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("把这一页转过的方向应用到其他每一页。")
        }
    }

    // MARK: top — the page, swipeable

    private var pagePane: some View {
        let _ = version   // reloads the image after a rotation
        return Group {
            #if os(iOS)
            TabView(selection: $pageIndex) {
                ForEach(Array(pages.enumerated()), id: \.offset) { i, url in
                    pageImage(url).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            #else
            VStack(spacing: 8) {
                pageImage(pages[min(pageIndex, pages.count - 1)])
                HStack {
                    Button("‹") { if pageIndex > 0 { pageIndex -= 1 } }
                    Text("\(pageIndex + 1) / \(pages.count)").font(.system(size: 12))
                    Button("›") { if pageIndex < pages.count - 1 { pageIndex += 1 } }
                }.padding(.bottom, 6)
            }
            #endif
        }
        .background(theme.surfaceSoft)
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

    // MARK: rotation

    @ToolbarContentBuilder private var rotateToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 14) {
                if sessionTurns % 4 != 0 {
                    Button("应用到全书") { showApplyAll = true }
                        .font(.system(size: 13)).foregroundStyle(theme.accentText)
                }
                Button { rotateCurrent() } label: { Image(systemName: "rotate.right") }
                    .accessibilityLabel("把这一页向右转 90°")
            }
        }
    }

    private func rotateCurrent() {
        guard let url = pages[safe: pageIndex] else { return }
        BookStore.rotatePage(url, quarterTurns: 1)
        sessionTurns += 1
        tokensByPage[pageIndex] = nil
        translations[pageIndex] = nil
        langByPage[pageIndex] = nil
        version += 1
        Task { await loadPage(pageIndex) }
    }

    // MARK: bottom — words, translation, pronunciation

    private var bottomPane: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    sourceSection
                    translationSection
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let selected { explanation(for: selected)
                .transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .background(theme.background)
    }

    @ViewBuilder private var sourceSection: some View {
        let lines = tokensByPage[pageIndex]
        if lines == nil {
            loadingRow("正在读这一页…")
        } else if lines?.isEmpty == true {
            Text("这一页没认出文字。").font(.system(size: 13)).foregroundStyle(theme.textMuted)
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(Array((lines ?? []).enumerated()), id: \.offset) { i, line in
                    HStack(alignment: .top, spacing: 6) {
                        playButton(id: "src-\(pageIndex)-\(i)",
                                   text: line.joined(separator: " "),
                                   language: langByPage[pageIndex])
                            .padding(.top, 2)
                        FlowLayout(spacing: 5) {
                            ForEach(Array(line.enumerated()), id: \.offset) { _, token in
                                wordChip(token)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var translationSection: some View {
        if let t = translations[pageIndex] {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("译文").font(.system(size: 11, weight: .medium)).foregroundStyle(theme.textMuted)
                transRow("English", t.en, id: "en-\(pageIndex)", language: "en-US")
                transRow("中文", t.zh, id: "zh-\(pageIndex)", language: "zh-CN")
            }
            .padding(.top, 4)
            .overlay(Rectangle().fill(theme.border.opacity(0.5)).frame(height: 1), alignment: .top)
            .padding(.top, Spacing.sm)
        } else if !(tokensByPage[pageIndex]?.isEmpty ?? true) && tokensByPage[pageIndex] != nil {
            loadingRow("正在译这一页…")
        }
    }

    private func transRow(_ label: String, _ value: String, id: String, language: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            playButton(id: id, text: value, language: language).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(theme.textMuted)
                Text(value).font(.system(size: 15)).lineSpacing(3)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
        .buttonStyle(.plain).disabled(key.isEmpty)
    }

    // The word explanation — the lower region of the "later half".
    @ViewBuilder private func explanation(for word: String) -> some View {
        let card = cards[word]
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 8) {
                Text(word).font(.system(size: 22, weight: .semibold)).foregroundStyle(theme.textPrimary)
                playButton(id: "word-\(word)", text: word, language: langByPage[pageIndex])
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

    // MARK: small pieces

    private func playButton(id: String, text: String, language: String?) -> some View {
        Button {
            speaker.toggle(id: id, text: text, language: language)
        } label: {
            Image(systemName: speaker.speakingId == id ? "stop.circle.fill" : "play.circle")
                .font(.system(size: 17))
                .foregroundStyle(speaker.speakingId == id ? theme.accentText : theme.textMuted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(speaker.speakingId == id ? "停止朗读" : "朗读")
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(theme.textMuted)
            Text(value.isEmpty ? "—" : value).font(.system(size: 16)).lineSpacing(3)
                .foregroundStyle(theme.textPrimary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadingRow(_ s: String) -> some View {
        HStack(spacing: 10) { ProgressView()
            Text(s).font(.system(size: 13)).foregroundStyle(theme.textSecondary) }
    }

    // MARK: work

    private func loadPage(_ page: Int) async {
        guard page < pages.count else { return }
        if tokensByPage[page] == nil {
            let text = await BookStore.ocrText(for: pages[page])
            var rows: [[String]] = []
            for rawLine in text.split(separator: "\n") {
                let words = rawLine.split(separator: " ").map(String.init)
                if !words.isEmpty { rows.append(words) }
            }
            let lang = Self.detectLanguage(text)
            await MainActor.run { tokensByPage[page] = rows; langByPage[page] = lang }
        }
        if translations[page] == nil, let t = await BookStore.translation(for: pages[page]) {
            await MainActor.run { translations[page] = (t.english, t.chinese) }
        }
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

    private static func detectLanguage(_ text: String) -> String? {
        let r = NLLanguageRecognizer()
        r.processString(text)
        return r.dominantLanguage?.rawValue      // e.g. "fr", "en", "zh-Hans"
    }

    private static func clean(_ token: String) -> String {
        token.trimmingCharacters(in: CharacterSet.alphanumerics.inverted
            .subtracting(CharacterSet(charactersIn: "'’-")))
            .trimmingCharacters(in: CharacterSet(charactersIn: "'’-"))
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
