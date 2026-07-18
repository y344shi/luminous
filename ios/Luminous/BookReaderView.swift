//
//  BookReaderView.swift
//  Luminous — 逐字读: read a scanned book, page by page, word by word.
//
//  A split reader that follows the device orientation: PORTRAIT stacks the page
//  on top and the reading area below; LANDSCAPE puts the page on the left and the
//  reading area on the right. A draggable handle resizes the split. The reading
//  area has a light "reference" card (the source paragraph as tappable words with
//  per-sentence play) and a study card (EN + 中文 translation + a few reading
//  notes, so you can read without tapping every word). Tap a word for its own
//  card. Pronunciation is Siri-voiced in each line's detected language. Pages can
//  be rotated (with apply-to-all) when the scanner got orientation wrong.
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
    @State private var split: CGFloat = 0.5       // portrait: top-pane fraction
    @State private var baseSplit: CGFloat = 0.5
    @State private var hsplit: CGFloat = 0.5       // landscape: left-pane fraction
    @State private var baseHSplit: CGFloat = 0.5
    @State private var tokensByPage: [Int: [[String]]] = [:]
    @State private var translations: [Int: (en: String, zh: String)] = [:]
    @State private var notesByPage: [Int: [String]] = [:]
    @State private var langByPage: [Int: String] = [:]
    @State private var selected: String?
    @State private var cards: [String: WordCard] = [:]
    @State private var sessionTurns = 0
    @State private var version = 0
    @State private var showApplyAll = false
    @State private var speaker = Speaker()

    private var pages: [URL] { book.pageURLs }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            if landscape {
                HStack(spacing: 0) {
                    pagePane.frame(width: max(220, min(geo.size.width - 280, geo.size.width * hsplit)))
                    handle(vertical: true, total: geo.size.width)
                    readingSection.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    pagePane.frame(height: max(150, min(geo.size.height - 220, geo.size.height * split)))
                    handle(vertical: false, total: geo.size.height)
                    readingSection.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
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
                for i in pages.indices where i != pageIndex { clearPage(i) }
                sessionTurns = 0
            }
            Button("取消", role: .cancel) {}
        } message: { Text("把这一页转过的方向应用到其他每一页。") }
    }

    // MARK: the page

    private var pagePane: some View {
        let _ = version
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
            } else { Color.clear }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(6)
    }

    // MARK: draggable handle (works both ways)

    private func handle(vertical: Bool, total: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(theme.surface)
            Capsule().fill(theme.textMuted.opacity(0.5))
                .frame(width: vertical ? 5 : 42, height: vertical ? 42 : 5)
        }
        .frame(width: vertical ? 22 : nil, height: vertical ? nil : 22)
        .frame(maxWidth: vertical ? nil : .infinity, maxHeight: vertical ? .infinity : nil)
        .overlay(Rectangle().fill(theme.border.opacity(0.5))
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1),
            alignment: vertical ? .leading : .top)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { v in
                    if vertical {
                        hsplit = min(0.7, max(0.3, baseHSplit + v.translation.width / max(total, 1)))
                    } else {
                        split = min(0.82, max(0.2, baseSplit + v.translation.height / max(total, 1)))
                    }
                }
                .onEnded { _ in baseSplit = split; baseHSplit = hsplit }
        )
        .accessibilityLabel("拖动调整比例")
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
        clearPage(pageIndex)
        version += 1
        Task { await loadPage(pageIndex) }
    }

    // MARK: the reading area

    private var readingSection: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    referenceCard
                    studyCard
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

    // The source, in a light "reference" card — tappable words + per-sentence play.
    @ViewBuilder private var referenceCard: some View {
        let lines = tokensByPage[pageIndex]
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("原文").font(.system(size: 11, weight: .medium)).foregroundStyle(theme.textMuted)
            if lines == nil {
                loadingRow("正在读这一页…")
            } else if lines?.isEmpty == true {
                Text("这一页没认出文字。").font(.system(size: 13)).foregroundStyle(theme.textMuted)
            } else {
                ForEach(Array((lines ?? []).enumerated()), id: \.offset) { i, line in
                    HStack(alignment: .top, spacing: 6) {
                        playButton(id: "src-\(pageIndex)-\(i)", text: line.joined(separator: " "),
                                   language: langByPage[pageIndex]).padding(.top, 2)
                        FlowLayout(spacing: 5) {
                            ForEach(Array(line.enumerated()), id: \.offset) { _, token in
                                wordChip(token)
                            }
                        }
                    }
                }
            }
        }
        .padding(Spacing.md).frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceSoft.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(theme.border.opacity(0.5), lineWidth: 1))
    }

    // The bigger study card — translation shown already + a few reading notes.
    @ViewBuilder private var studyCard: some View {
        let hasText = tokensByPage[pageIndex] != nil && !(tokensByPage[pageIndex]?.isEmpty ?? true)
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let t = translations[pageIndex] {
                transRow("English", t.en, id: "en-\(pageIndex)", language: "en-US")
                transRow("中文", t.zh, id: "zh-\(pageIndex)", language: "zh-CN")
            } else if hasText {
                loadingRow("正在译这一页…")
            }
            if let notes = notesByPage[pageIndex], !notes.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("读书笔记").font(.system(size: 11, weight: .medium)).foregroundStyle(theme.textMuted)
                    ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                        HStack(alignment: .top, spacing: 6) {
                            Text("·").foregroundStyle(theme.accentText)
                            Text(note).font(.system(size: 15)).lineSpacing(3)
                                .foregroundStyle(theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 2)
                .overlay(Rectangle().fill(theme.border.opacity(0.5)).frame(height: 1), alignment: .top)
                .padding(.top, Spacing.sm)
            } else if hasText && WordStudy.isAvailable {
                loadingRow("正在写笔记…")
            }
        }
        .padding(Spacing.md).frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(theme.border, lineWidth: 1))
    }

    private func transRow(_ label: String, _ value: String, id: String, language: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            playButton(id: id, text: value, language: language).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(theme.textMuted)
                Text(value).font(.system(size: 15)).lineSpacing(3)
                    .foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
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
            Text(token).font(.system(size: 19)).lineSpacing(4)
                .foregroundStyle(isSel ? theme.accentText : theme.textPrimary)
                .padding(.horizontal, 3).padding(.vertical, 1)
                .background(isSel ? theme.accentSoft : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain).disabled(key.isEmpty)
    }

    @ViewBuilder private func explanation(for word: String) -> some View {
        let card = cards[word]
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 8) {
                Text(word).font(.system(size: 22, weight: .semibold)).foregroundStyle(theme.textPrimary)
                playButton(id: "word-\(word)", text: word, language: langByPage[pageIndex])
                Spacer()
                Button { withAnimation(.easeOut(duration: 0.2)) { selected = nil } } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 18))
                        .foregroundStyle(theme.textMuted.opacity(0.7))
                }.buttonStyle(.plain).accessibilityLabel("收起")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if let card {
                        row("English", card.english); row("中文", card.chinese)
                        row("语法", card.grammar); row("用法", card.usage); row("例句", card.example)
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
        .padding(Spacing.md).frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: 260)
        .background(theme.surface)
        .overlay(Rectangle().fill(theme.border.opacity(0.6)).frame(height: 1), alignment: .top)
    }

    // MARK: small pieces

    private func playButton(id: String, text: String, language: String?) -> some View {
        Button { speaker.toggle(id: id, text: text, language: language) } label: {
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
        if notesByPage[page] == nil, let n = await BookStore.notes(for: pages[page]) {
            await MainActor.run { notesByPage[page] = n }
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

    private func clearPage(_ i: Int) {
        tokensByPage[i] = nil; translations[i] = nil; notesByPage[i] = nil; langByPage[i] = nil
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
        let r = NLLanguageRecognizer(); r.processString(text)
        return r.dominantLanguage?.rawValue
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
