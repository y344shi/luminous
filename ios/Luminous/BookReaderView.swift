//
//  BookReaderView.swift
//  Luminous — 逐字读: read a scanned book, page by page, word by word.
//
//  Three adjustable regions — the PAGE, the 原文 reference card, and the
//  explanation card — laid out to the device orientation (portrait stacks them;
//  landscape puts the page on the left, the two cards on the right). The page is
//  pinch-zoomable (double-tap to reset; when zoomed, one finger pans); a draggable
//  handle sizes the page, and a thin dotted handle sizes reference vs explanation.
//  The reference card's font is adjustable. Translation + a few 读书笔记 show
//  already; tap a word for its own card; play buttons speak in the detected
//  language (Siri voice). Rotate fixes a mis-oriented scan (with apply-to-all).
//  Queued (WORD-STUDY-PLAN.md): two-finger swipe to page while zoomed.
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
    @State private var split: CGFloat = 0.5        // portrait: page fraction
    @State private var baseSplit: CGFloat = 0.5
    @State private var hsplit: CGFloat = 0.5        // landscape: page fraction
    @State private var baseHSplit: CGFloat = 0.5
    @State private var readSplit: CGFloat = 0.42    // reference vs explanation
    @State private var baseReadSplit: CGFloat = 0.42
    @State private var fontScale: CGFloat = 1.0
    @State private var tokensByPage: [Int: [[String]]] = [:]
    @State private var translations: [Int: (en: String, zh: String)] = [:]
    @State private var notesByPage: [Int: [String]] = [:]
    @State private var langByPage: [Int: String] = [:]
    @State private var selected: String?
    @State private var cards: [String: WordCard] = [:]
    @State private var sessionTurns = 0
    @State private var version = 0
    @State private var showApplyAll = false
    @State private var showAnnotator = false
    @State private var textTarget: TextTarget?
    @State private var speaker = Speaker()

    #if canImport(UIKit)
    struct TextTarget: Identifiable { let id = UUID(); let url: URL; let image: UIImage }
    #endif

    private var pages: [URL] { book.pageURLs }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            if landscape {
                HStack(spacing: 0) {
                    pagePane.frame(width: max(220, min(geo.size.width - 300, geo.size.width * hsplit)))
                    handle(vertical: true, total: geo.size.width)
                    readingArea.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    pagePane.frame(height: max(150, min(geo.size.height - 240, geo.size.height * split)))
                    handle(vertical: false, total: geo.size.height)
                    readingArea.frame(maxWidth: .infinity, maxHeight: .infinity)
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
                BookStore.rotateAll(bookID: book.id, quarterTurns: sessionTurns, except: pages[safe: pageIndex])
                for i in pages.indices where i != pageIndex { clearPage(i) }
                sessionTurns = 0
            }
            Button("取消", role: .cancel) {}
        } message: { Text("把这一页转过的方向应用到其他每一页。") }
        #if canImport(PencilKit) && os(iOS)
        .fullScreenCover(isPresented: $showAnnotator) {
            if let url = pages[safe: pageIndex], let data = BookStore.data(for: url),
               let ui = UIImage(data: data) {
                PageAnnotator(pageURL: url, image: ui) {
                    showAnnotator = false
                    version += 1          // refresh the composited page overlay
                }
            }
        }
        .fullScreenCover(item: $textTarget) { t in
            PageTextReader(pageURL: t.url, image: t.image, language: langByPage[pageIndex]) {
                textTarget = nil
            }
        }
        #endif
    }

    // MARK: the page (pinch-zoomable)

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

    @ViewBuilder private func pageImage(_ url: URL) -> some View {
        #if canImport(UIKit)
        if let ui = compositedUIImage(for: url) {
            ZoomableImage(image: Image(uiImage: ui),
                          onDoubleTap: { textTarget = TextTarget(url: url, image: ui) })
                .id("\(url.lastPathComponent)-\(version)").padding(6)
        } else { Color.clear }
        #else
        if let data = BookStore.data(for: url), let img = platformImage(data) {
            ZoomableImage(image: img).id(url).padding(6)
        } else { Color.clear }
        #endif
    }

    #if canImport(UIKit)
    /// The page with its hand annotation drawn on top (same aspect → aligned),
    /// so the two zoom and pan together.
    private func compositedUIImage(for url: URL) -> UIImage? {
        guard let data = BookStore.data(for: url), let page = UIImage(data: data) else { return nil }
        guard let pngData = BookStore.annotationPNG(for: url), let ann = UIImage(data: pngData)
        else { return page }
        let format = UIGraphicsImageRendererFormat.default(); format.scale = page.scale
        return UIGraphicsImageRenderer(size: page.size, format: format).image { _ in
            page.draw(in: CGRect(origin: .zero, size: page.size))
            ann.draw(in: CGRect(origin: .zero, size: page.size))
        }
    }
    #endif

    // MARK: handles

    private func handle(vertical: Bool, total: CGFloat) -> some View {
        ZStack {
            Capsule().fill(theme.textMuted.opacity(0.35))
                .frame(width: vertical ? 4 : 40, height: vertical ? 40 : 4)
        }
        .frame(width: vertical ? 20 : nil, height: vertical ? nil : 20)
        .frame(maxWidth: vertical ? nil : .infinity, maxHeight: vertical ? .infinity : nil)
        .background(theme.background)
        .overlay(Rectangle().fill(theme.border.opacity(0.4))
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1),
            alignment: vertical ? .leading : .top)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { v in
                    if vertical { hsplit = min(0.7, max(0.3, baseHSplit + v.translation.width / max(total, 1))) }
                    else { split = min(0.85, max(0.18, baseSplit + v.translation.height / max(total, 1))) }
                }
                .onEnded { _ in baseSplit = split; baseHSplit = hsplit }
        )
        .accessibilityLabel("拖动调整比例")
    }

    private func dottedHandle(total H: CGFloat) -> some View {
        ZStack {
            DashedLine().stroke(theme.textMuted.opacity(0.5),
                                style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(height: 1)
            Capsule().fill(theme.textMuted.opacity(0.4)).frame(width: 34, height: 4)
        }
        .frame(height: 20).frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { v in readSplit = min(0.85, max(0.15, baseReadSplit + v.translation.height / max(H, 1))) }
                .onEnded { _ in baseReadSplit = readSplit }
        )
        .accessibilityLabel("拖动调整原文与解释的比例")
    }

    // MARK: rotation

    @ToolbarContentBuilder private var rotateToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 14) {
                if sessionTurns % 4 != 0 {
                    Button("应用到全书") { showApplyAll = true }
                        .font(.system(size: 13)).foregroundStyle(theme.accentText)
                }
                #if canImport(PencilKit) && os(iOS)
                if SketchNote.canDraw {
                    Button { showAnnotator = true } label: { Image(systemName: "pencil.tip.crop.circle") }
                        .accessibilityLabel("用铅笔批注这一页")
                }
                #endif
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

    // MARK: reading area — reference card | dotted handle | explanation card

    private var readingArea: some View {
        GeometryReader { g in
            let refH = max(90, min(g.size.height - 110, g.size.height * readSplit))
            VStack(spacing: 0) {
                referenceCard.frame(height: refH)
                dottedHandle(total: g.size.height)
                explanationCard.frame(maxHeight: .infinity)
            }
        }
        .background(theme.background)
    }

    private var referenceCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("原文").font(.system(size: 11, weight: .medium)).foregroundStyle(theme.textMuted)
                Spacer()
                Button { fontScale = max(0.7, fontScale - 0.1) } label: {
                    Text("A").font(.system(size: 12)).foregroundStyle(theme.textSecondary)
                }.buttonStyle(.plain).accessibilityLabel("字小一点")
                Button { fontScale = min(1.8, fontScale + 0.1) } label: {
                    Text("A").font(.system(size: 18)).foregroundStyle(theme.textSecondary)
                }.buttonStyle(.plain).accessibilityLabel("字大一点")
            }
            ScrollView { sourceLines.frame(maxWidth: .infinity, alignment: .leading) }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceSoft.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(theme.border.opacity(0.5), lineWidth: 1))
        .padding([.horizontal, .top], Spacing.md)
    }

    @ViewBuilder private var sourceLines: some View {
        let lines = tokensByPage[pageIndex]
        if lines == nil {
            loadingRow("正在读这一页…")
        } else if lines?.isEmpty == true {
            Text("这一页没认出文字。").font(.system(size: 13)).foregroundStyle(theme.textMuted)
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(Array((lines ?? []).enumerated()), id: \.offset) { i, line in
                    HStack(alignment: .top, spacing: 6) {
                        playButton(id: "src-\(pageIndex)-\(i)", text: line.joined(separator: " "),
                                   language: langByPage[pageIndex]).padding(.top, 2)
                        FlowLayout(spacing: 5) {
                            ForEach(Array(line.enumerated()), id: \.offset) { _, token in wordChip(token) }
                        }
                    }
                }
            }
        }
    }

    private var explanationCard: some View {
        let hasText = tokensByPage[pageIndex] != nil && !(tokensByPage[pageIndex]?.isEmpty ?? true)
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let word = selected { wordCardView(word) }
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
                                    .foregroundStyle(theme.textPrimary).fixedSize(horizontal: false, vertical: true)
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
        }
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(theme.border, lineWidth: 1))
        .padding([.horizontal, .bottom], Spacing.md)
    }

    // MARK: pieces

    @ViewBuilder private func wordCardView(_ word: String) -> some View {
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
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.accentSoft.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            Text(token).font(.system(size: 19 * fontScale)).lineSpacing(4)
                .foregroundStyle(isSel ? theme.accentText : theme.textPrimary)
                .padding(.horizontal, 3).padding(.vertical, 1)
                .background(isSel ? theme.accentSoft : Color.clear, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain).disabled(key.isEmpty)
    }

    private func playButton(id: String, text: String, language: String?) -> some View {
        Button { speaker.toggle(id: id, text: text, language: language) } label: {
            Image(systemName: speaker.speakingId == id ? "stop.circle.fill" : "play.circle")
                .font(.system(size: 17))
                .foregroundStyle(speaker.speakingId == id ? theme.accentText : theme.textMuted)
        }
        .buttonStyle(.plain).accessibilityLabel(speaker.speakingId == id ? "停止朗读" : "朗读")
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
            .first(where: { $0.map(Self.clean).contains(word) })?.joined(separator: " ") ?? word
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

// MARK: - a pinch-zoomable image (double-tap resets; one finger pans when zoomed)

private struct ZoomableImage: View {
    let image: Image
    var onDoubleTap: (() -> Void)? = nil
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        let base = image.resizable().scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { v in scale = min(6, max(1, lastScale * v)) }
                    .onEnded { _ in lastScale = scale; if scale <= 1.001 { reset() } }
            )
            // Double-tap opens the full-screen read-on-photo view (or resets zoom
            // when there's no handler). Pinching back to 1× still resets.
            .onTapGesture(count: 2) {
                if let onDoubleTap { onDoubleTap() }
                else { withAnimation(.easeInOut(duration: 0.2)) { reset() } }
            }
            .clipped()

        // Only intercept one-finger drags (pan) once zoomed, so the pager keeps
        // its swipe at 1×.
        if scale > 1 {
            base.highPriorityGesture(
                DragGesture()
                    .onChanged { v in
                        offset = CGSize(width: lastOffset.width + v.translation.width,
                                        height: lastOffset.height + v.translation.height)
                    }
                    .onEnded { _ in lastOffset = offset }
            )
        } else {
            base
        }
    }

    private func reset() { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }
}

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return p
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
