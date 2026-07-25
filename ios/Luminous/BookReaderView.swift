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
#if canImport(PencilKit) && os(iOS)
import PencilKit
#endif

struct BookReaderView: View {
    let book: Book
    @Environment(\.theme) private var theme

    @State private var pageIndex = 0
    @State private var split: CGFloat = 0.5        // portrait: page fraction
    @State private var baseSplit: CGFloat = 0.5
    @State private var hsplit: CGFloat = 0.5        // landscape: page fraction
    @State private var baseHSplit: CGFloat = 0.5
    @State private var tokensByPage: [Int: [[String]]] = [:]
    @State private var translations: [Int: (en: String, zh: String)] = [:]
    @State private var notesByPage: [Int: [String]] = [:]
    @State private var langByPage: [Int: String] = [:]
    @State private var sessionTurns = 0
    @State private var version = 0
    @State private var showApplyAll = false
    @State private var showAnnotator = false
    @State private var speaker = Speaker()
    @State private var pageNote: String?          // per-page lesson kept with the book
    @State private var editingNote = false
    @State private var noteLoading = false
    // Words highlighted right on the page in the split view
    @State private var boxesByPage: [Int: [WordBox]] = [:]
    @State private var showWords = true
    @State private var inking = false
    @State private var selectedWord: String?
    @State private var wordCard: WordCard?
    @State private var wordLoading = false

    #if canImport(UIKit)
    @State private var textTarget: TextTarget?
    struct TextTarget: Identifiable { let id = UUID(); let url: URL; let image: UIImage }
    #endif

    private var pages: [URL] { book.pageURLs }

    /// Side-by-side only where there's real width. On iPhone the split is ALWAYS
    /// vertical (page up, lesson down) — even held sideways, two columns on a
    /// phone leave both halves too narrow to read.
    private var allowsSideBySide: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom != .phone
        #else
        return true
        #endif
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = allowsSideBySide && geo.size.width > geo.size.height
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
        .onChange(of: pageIndex) { _, _ in sessionTurns = 0; speaker.stop() }
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
            PageTextReader(pages: pages,
                           startIndex: pages.firstIndex(of: t.url) ?? pageIndex,
                           bookID: book.id,
                           imageFor: { compositedUIImage(for: $0) }) {
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
        #if canImport(PencilKit) && os(iOS)
        if inking, url == pages[safe: pageIndex], let ui = compositedUIImage(for: url) {
            InkablePage(pageURL: url, image: ui)
                .id("ink-\(url.lastPathComponent)")
                .padding(6)
        } else if let ui = compositedUIImage(for: url) {
            ZoomableImage(image: Image(uiImage: ui),
                          imageSize: ui.size,
                          boxes: showWords ? (boxesByPage[pageIndex] ?? []) : [],
                          selectedWord: selectedWord,
                          onWordTap: { box in tapWord(box) },
                          onDoubleTap: { textTarget = TextTarget(url: url, image: ui) })
                .id("\(url.lastPathComponent)-\(version)-\(showWords)").padding(6)
        } else { Color.clear }
        #elseif canImport(UIKit)
        if let ui = compositedUIImage(for: url) {
            ZoomableImage(image: Image(uiImage: ui),
                          imageSize: ui.size,
                          boxes: showWords ? (boxesByPage[pageIndex] ?? []) : [],
                          selectedWord: selectedWord,
                          onWordTap: { box in tapWord(box) },
                          onDoubleTap: { textTarget = TextTarget(url: url, image: ui) })
                .id("\(url.lastPathComponent)-\(version)-\(showWords)").padding(6)
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
        VStack(spacing: 0) {
            pageActionBar
            pageLessonCard.frame(maxHeight: .infinity)
        }
        .background(theme.background)
    }

    /// A compact strip instead of the old wall of word chips: read the WHOLE page
    /// aloud, or go tap words directly on the photo (where highlighting lives).
    private var pageActionBar: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if pageIndex == 0 { bookOverviewLink }
            FlowLayout(spacing: Spacing.sm) {
                Button { readWholePage() } label: {
                    Label(speaker.speakingId == "page" ? "停止" : "读整页",
                          systemImage: speaker.speakingId == "page" ? "stop.circle.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(theme.accentText)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(theme.accent.opacity(0.16), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(pageText.isEmpty)

                #if canImport(PencilKit) && os(iOS)
                Button { withAnimation { inking.toggle() }; if !inking { version += 1 } } label: {
                    Label(inking ? "写完了" : "笔",
                          systemImage: inking ? "checkmark.circle.fill" : "pencil.tip")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(inking ? theme.accentText : theme.textSecondary)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(inking ? theme.accent.opacity(0.16) : theme.surfaceSoft, in: Capsule())
                }.buttonStyle(.plain)
                #endif

                Button { withAnimation { showWords.toggle() } } label: {
                    Label(showWords ? "词已标出" : "标出可点的词",
                          systemImage: showWords ? "highlighter" : "hand.tap")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(showWords ? theme.accentText : theme.textSecondary)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(showWords ? theme.accent.opacity(0.16) : theme.surfaceSoft, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled((boxesByPage[pageIndex] ?? []).isEmpty)

                #if canImport(UIKit)
                Button {
                    if let url = pages[safe: pageIndex], let ui = compositedUIImage(for: url) {
                        textTarget = TextTarget(url: url, image: ui)
                    }
                } label: {
                    Label("全屏", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(theme.surfaceSoft, in: Capsule())
                }.buttonStyle(.plain)
                #endif

                Button { readLesson() } label: {
                    Label(speaker.speakingId == "lesson" ? "停止" : "读讲解",
                          systemImage: speaker.speakingId == "lesson" ? "stop.circle.fill" : "text.bubble")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(theme.accentText)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(theme.accent.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled((pageNote ?? "").isEmpty)

                Button { editingNote = true } label: {
                    Label("编辑", systemImage: "square.and.pencil")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(theme.surfaceSoft, in: Capsule())
                }.buttonStyle(.plain)

                Button { regeneratePageLesson() } label: {
                    Label("重新生成", systemImage: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(theme.surfaceSoft, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(noteLoading)
            }
        }
        .padding(.horizontal, Spacing.md).padding(.top, Spacing.sm).padding(.bottom, 4)
        .sheet(isPresented: $editingNote) {
            PageNoteEditorView(text: pageNote ?? "", page: pageIndex + 1) { saved in
                if let url = pages[safe: pageIndex] {
                    BookStore.savePageNote(saved, for: url)
                    pageNote = saved.isEmpty ? nil : saved
                }
            }
        }
    }

    /// The page's course — auto-populated on first open, then yours to edit.
    private var pageLessonCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                inlineWordCard
                if let note = pageNote, !note.isEmpty {
                    Text(renderedNote(note))
                        .font(.system(size: 15)).lineSpacing(4)
                        .textSelection(.enabled)
                        .foregroundStyle(theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Divider().padding(.vertical, 2)
                    DeepenSection(topic: "第 \(pageIndex + 1) 页",
                                  context: pageText,
                                  language: langByPage[pageIndex]) { note }
                        .id("deep-\(pageIndex)")
                } else if noteLoading {
                    loadingRow("正在写这一页的课…")
                } else if pageText.isEmpty {
                    Text("这一页没认出文字。").font(.system(size: 13)).foregroundStyle(theme.textMuted)
                } else {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("这一页还没有课。可以让 AI 写一份，或者自己粘一份进来。")
                            .font(.system(size: 14)).lineSpacing(3).foregroundStyle(theme.textSecondary)
                        HStack(spacing: Spacing.sm) {
                            SoftButton(title: "生成这一页的课", variant: .solid, full: false) {
                                regeneratePageLesson()
                            }
                            SoftButton(title: "粘贴", variant: .ghost, full: false) { editingNote = true }
                            Spacer()
                        }
                    }
                }
            }
            .padding(Spacing.md).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(theme.border, lineWidth: 1))
        .padding([.horizontal, .bottom], Spacing.md)
    }

    private func renderedNote(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s,
                               options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(s)
    }

    /// Tapping a word right on the page: show its card instantly when the
    /// pre-warm pass already explained it, otherwise ask and wait.
    private func tapWord(_ box: WordBox) {
        let key = ZoomableImage.clean(box.text)
        guard !key.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.15)) { selectedWord = key }
        if let cached = WordCardStore.card(key, book: book.id) {
            wordCard = cached; wordLoading = false; return
        }
        wordCard = nil; wordLoading = true
        let ctx = sentenceContext(for: box.text)
        Task {
            let c = await WordStudy.base(for: key, context: ctx)
            await MainActor.run {
                wordLoading = false
                if selectedWord == key { wordCard = c }
            }
            if let c { WordCardStore.put(c, book: book.id) }
        }
    }

    /// The sentence the tapped word sits in, from this page's text.
    private func sentenceContext(for word: String) -> String {
        let w = ZoomableImage.clean(word)
        let full = pageText
        guard !full.isEmpty, !w.isEmpty else { return word }
        for s in full.components(separatedBy: CharacterSet(charactersIn: ".!?。！？…\n")) {
            if s.range(of: w, options: .caseInsensitive) != nil {
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { return t }
            }
        }
        return full
    }

    /// The tapped word's card, above the page's course.
    @ViewBuilder private var inlineWordCard: some View {
        if let w = selectedWord {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(w).font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Button { speaker.toggle(id: "w-\(w)", text: w, language: langByPage[pageIndex]) } label: {
                        Image(systemName: speaker.speakingId == "w-\(w)" ? "stop.circle.fill" : "play.circle")
                            .font(.system(size: 16)).foregroundStyle(theme.accentText)
                    }.buttonStyle(.plain)
                    Spacer()
                    Button {
                        withAnimation { selectedWord = nil; wordCard = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16)).foregroundStyle(theme.textMuted.opacity(0.7))
                    }.buttonStyle(.plain)
                }
                if let c = wordCard {
                    Text("\(c.english) ／ \(c.chinese)")
                        .font(.system(size: 15)).foregroundStyle(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !c.grammar.isEmpty {
                        Text(c.grammar).font(.system(size: 13)).foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !c.example.isEmpty {
                        Text(c.example).font(.system(size: 13)).italic()
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if wordLoading {
                    HStack(spacing: 8) { ProgressView().controlSize(.small)
                        Text("正在想…").font(.system(size: 13)).foregroundStyle(theme.textMuted) }
                } else {
                    Text("这个词还没有解释。").font(.system(size: 13)).foregroundStyle(theme.textMuted)
                }
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.accent.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    /// Read the page's course aloud — each line in the voice its language needs
    /// (中文 explanation in 中文, the book's own language for the examples).
    private func readLesson() {
        if speaker.speakingId == "lesson" { speaker.stop(); return }
        guard let note = pageNote, !note.isEmpty else { return }
        let segs = LessonSpeech.segments(for: note, foreignLanguage: langByPage[pageIndex])
        guard !segs.isEmpty else { return }
        speaker.speakSequence(id: "lesson", segments: segs)
    }

    /// Read the WHOLE page in one go (not line by line).
    private func readWholePage() {
        if speaker.speakingId == "page" { speaker.stop(); return }
        let t = pageText
        guard !t.isEmpty else { return }
        speaker.toggle(id: "page", text: t, language: langByPage[pageIndex])
    }

    private func regeneratePageLesson() {
        guard let url = pages[safe: pageIndex], !noteLoading else { return }
        noteLoading = true
        Task {
            let out = await BookExport.pageLesson(for: url, force: true)
            await MainActor.run {
                noteLoading = false
                if let out { pageNote = out }
            }
        }
    }



    private var bookOverviewLink: some View {
        NavigationLink { BookOverviewView(book: book) } label: {
            HStack(spacing: 8) {
                Image(systemName: "text.book.closed").font(.system(size: 14))
                    .foregroundStyle(theme.accentText)
                VStack(alignment: .leading, spacing: 1) {
                    Text("本书词汇与语法").font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text("按频率的生词表 + 整本书的课").font(.system(size: 11))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.textMuted)
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.accent.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }


    /// This page's source text (context for "再讲深一点").
    private var pageText: String {
        (tokensByPage[pageIndex] ?? []).map { $0.joined(separator: " ") }.joined(separator: " ")
    }



    // MARK: pieces





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
        await MainActor.run { pageNote = BookStore.pageNote(for: pages[page]) }
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
        // Word boxes, so the page itself can highlight what's tappable.
        if boxesByPage[page] == nil {
            let b = await BookStore.wordBoxes(for: pages[page])
            await MainActor.run { boxesByPage[page] = b }
        }

        // Explain this page's words in the background, so tapping any of them
        // (here or in the full-screen photo reader) opens instantly.
        WordCardStore.prewarm(pageURL: pages[page], book: book.id)

        // The page's course IS its note: pre-populate when empty, never overwrite
        // what the user wrote or pasted.
        let existing = BookStore.pageNote(for: pages[page])
        if existing?.isEmpty != false {
            await MainActor.run { noteLoading = true }
            let out = await BookExport.pageLesson(for: pages[page])
            await MainActor.run {
                noteLoading = false
                if page == pageIndex, let out { pageNote = out }
            }
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

#if canImport(PencilKit) && os(iOS)
/// The page with a PencilKit canvas laid straight over it, so you can annotate
/// in the split view without opening the full-screen annotator. Saves as you
/// draw (and on leaving), into the same `.ann` sidecar.
private struct InkablePage: View {
    let pageURL: URL
    let image: UIImage
    @State private var drawing = PKDrawing()
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let rect = fitted(in: geo.size)
            ZStack {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(width: rect.width, height: rect.height)
                AnnotationCanvas(drawing: $drawing)
                    .frame(width: rect.width, height: rect.height)
            }
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .onAppear {
                canvasSize = rect.size
                if let data = BookStore.annotation(for: pageURL),
                   let d = try? PKDrawing(data: data) { drawing = d }
            }
            .onChange(of: rect.size) { _, new in canvasSize = new }
        }
        .onDisappear { save() }
    }

    private func save() {
        guard !drawing.strokes.isEmpty else {
            BookStore.saveAnnotation(nil, png: nil, for: pageURL); return
        }
        let size = canvasSize == .zero ? CGSize(width: 1, height: 1) : canvasSize
        let png = drawing.image(from: CGRect(origin: .zero, size: size),
                                scale: UIScreen.main.scale).pngData()
        BookStore.saveAnnotation(drawing.dataRepresentation(), png: png, for: pageURL)
    }

    private func fitted(in container: CGSize) -> CGRect {
        guard image.size.width > 0, image.size.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let s = min(container.width / image.size.width, container.height / image.size.height)
        return CGRect(origin: .zero,
                      size: CGSize(width: image.size.width * s, height: image.size.height * s))
    }
}
#endif

private struct ZoomableImage: View {
    let image: Image
    /// Pixel size of the image, so word boxes can be laid out over it.
    var imageSize: CGSize = .zero
    /// Recognized words to highlight right on the page (tap → explain).
    var boxes: [WordBox] = []
    var selectedWord: String? = nil
    var onWordTap: ((WordBox) -> Void)? = nil
    var onDoubleTap: (() -> Void)? = nil

    @Environment(\.theme) private var theme
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        let base = imageWithWords
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

    /// The page, with every recognized word marked and tappable — so you can
    /// study straight from the split view, without going full-screen.
    private var imageWithWords: some View {
        GeometryReader { geo in
            let rect = fitted(in: geo.size)
            ZStack(alignment: .topLeading) {
                image.resizable().frame(width: rect.width, height: rect.height)
                if !boxes.isEmpty {
                    ForEach(Array(boxes.enumerated()), id: \.offset) { _, box in
                        wordRegion(box, in: rect.size)
                    }
                }
            }
            .frame(width: rect.width, height: rect.height)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    private func wordRegion(_ box: WordBox, in size: CGSize) -> some View {
        let isSel = selectedWord != nil && ZoomableImage.clean(box.text) == selectedWord
        let w = box.w * size.width, h = box.h * size.height
        let cx = (box.x + box.w / 2) * size.width
        let cy = (1 - (box.y + box.h / 2)) * size.height
        return RoundedRectangle(cornerRadius: 3)
            .fill(isSel ? theme.accent.opacity(0.40) : Color.yellow.opacity(0.22))
            .overlay(RoundedRectangle(cornerRadius: 3)
                .stroke(isSel ? theme.accentText.opacity(0.9) : theme.accentText.opacity(0.35),
                        lineWidth: isSel ? 1.5 : 0.6))
            .frame(width: max(w, 8), height: max(h, 8))
            .contentShape(Rectangle())
            .onTapGesture { onWordTap?(box) }
            .position(x: cx, y: cy)
    }

    /// The image's drawn rect inside `container` (scaledToFit maths, so the word
    /// boxes land exactly where the words are).
    private func fitted(in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let s = min(container.width / imageSize.width, container.height / imageSize.height)
        return CGRect(origin: .zero,
                      size: CGSize(width: imageSize.width * s, height: imageSize.height * s))
    }

    static func clean(_ token: String) -> String {
        token.trimmingCharacters(in: CharacterSet.alphanumerics.inverted
            .subtracting(CharacterSet(charactersIn: "'’-")))
            .trimmingCharacters(in: CharacterSet(charactersIn: "'’-"))
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

/// Read / edit a page's kept lesson. Starts in read mode when there's content
/// (rendered Markdown, selectable), or straight into editing when empty.
struct PageNoteEditorView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let page: Int
    let onSave: (String) -> Void

    @State private var text: String
    @State private var editing: Bool
    @State private var speaker = Speaker()

    init(text: String, page: Int, onSave: @escaping (String) -> Void) {
        self.page = page; self.onSave = onSave
        _text = State(initialValue: text)
        _editing = State(initialValue: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        NavigationStack {
            Group {
                if editing {
                    TextEditor(text: $text)
                        .font(.system(size: 14)).lineSpacing(3)
                        .padding(8)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(theme.border, lineWidth: 1))
                        .padding(Spacing.lg)
                } else {
                    ScrollView {
                        Text(rendered).font(.system(size: 15)).lineSpacing(4)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.lg)
                            .foregroundStyle(theme.textPrimary)
                    }
                }
            }
            .themedScreen()
            .navigationTitle("第 \(page) 页 · 课")
            .inlineNavTitle()
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button("完成") { onSave(text); speaker.stop(); dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(editing ? "预览" : "编辑") { editing.toggle() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !editing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { readAloud() } label: {
                        Image(systemName: speaker.speakingId == "note" ? "stop.circle.fill" : "speaker.wave.2")
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("朗读本页课")
                }
                #endif
            }
            .onDisappear { speaker.stop() }
        }
    }

    private func readAloud() {
        if speaker.speakingId == "note" { speaker.stop(); return }
        let segs = LessonSpeech.segments(for: text)
        guard !segs.isEmpty else { return }
        speaker.speakSequence(id: "note", segments: segs)
    }

    private var rendered: AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}
