//
//  PageTextReader.swift
//  Luminous — 逐字读: read the words ON the photo, full-screen, swipeable.
//
//  A full-screen pager over the book's pages. Each page shows the scanned photo
//  with every recognized word marked and tappable — tap a word for its card. The
//  page translation ("the lesson") is placed in the page's WHITE SPACE (a band
//  with no words) so it never covers text; it hides while you pinch-zoom. 朗读整页
//  reads the whole page in its own language (French book → French voice). Pinch
//  to zoom / double-tap to reset; swipe left/right for the next/previous page
//  (single-finger pan only kicks in once zoomed). iOS/iPadOS.
//

import SwiftUI
import NaturalLanguage

#if canImport(UIKit)
import UIKit

/// A little move-and-shrink transform for a floating panel: a drag offset plus a
/// render scale, each with a "last" value so gestures resume from where they left.
private struct Movable: Equatable {
    var offset: CGSize = .zero
    var lastOffset: CGSize = .zero
    var scale: CGFloat = 1
    var lastScale: CGFloat = 1
}

struct PageTextReader: View {
    let pages: [URL]
    let imageFor: (URL) -> UIImage?
    var onClose: () -> Void
    @State private var index: Int

    init(pages: [URL], startIndex: Int, imageFor: @escaping (URL) -> UIImage?,
         onClose: @escaping () -> Void) {
        self.pages = pages; self.imageFor = imageFor; self.onClose = onClose
        _index = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(pages.enumerated()), id: \.offset) { i, url in
                    PageTextContent(pageURL: url, image: imageFor(url)).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))
            .ignoresSafeArea()

            Button { onClose() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28)).symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.45))
            }.buttonStyle(.plain).padding()
        }
    }
}

private struct PageTextContent: View {
    let pageURL: URL
    let image: UIImage?

    @Environment(\.theme) private var theme
    @State private var boxes: [WordBox] = []
    @State private var loaded = false
    @State private var selected: String?
    @State private var cards: [String: WordCard] = [:]
    @State private var pageTrans: (en: String, zh: String)?
    @State private var transTried = false
    @State private var fullText = ""
    @State private var language: String?
    @State private var lesson: [LessonStep]?
    @State private var lessonLoading = false
    @State private var showLesson = false
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var speaker = Speaker()
    @State private var cardMove = Movable()      // the word-card / translation panel
    @State private var lessonMove = Movable()    // the 小课 panel

    var body: some View {
        GeometryReader { geo in
            let rect = fittedRect(imageSize: image?.size ?? .zero, in: geo.size)
            let originX = (geo.size.width - rect.width) / 2
            let originY = (geo.size.height - rect.height) / 2
            ZStack {
                // The page + word highlights (share the zoom transform).
                ZStack(alignment: .topLeading) {
                    if let image { Image(uiImage: image).resizable().frame(width: rect.width, height: rect.height) }
                    ForEach(Array(boxes.enumerated()), id: \.offset) { _, box in
                        wordRegion(box, in: rect.size)
                    }
                }
                .frame(width: rect.width, height: rect.height)
                .scaleEffect(scale).offset(offset)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                .gesture(magnifyGesture)
                // Pan only bites once zoomed; at 1× the drag is disabled so the
                // TabView pages across the whole photo, not just the margins.
                .gesture(panGesture, including: scale > 1.001 ? .all : .none)
                .onTapGesture(count: 2) { withAnimation(.easeInOut(duration: 0.2)) { resetZoom() } }

                // Full-page read + the little lesson, top-left.
                VStack {
                    HStack(spacing: 8) {
                        pillButton(playing: speaker.speakingId == "page-src",
                                   icon: "play.circle.fill", title: "朗读整页") {
                            speaker.toggle(id: "page-src", text: fullText, language: language)
                        }.opacity(fullText.isEmpty ? 0 : 1)
                        pillButton(playing: showLesson, icon: "text.book.closed", title: "小课") {
                            openLesson()
                        }.opacity(fullText.isEmpty ? 0 : 1)
                        Spacer()
                    }.padding([.leading, .top]).padding(.top, 4)
                    Spacer()
                }

                // The page translation, placed in the page's white space; the
                // tapped-word card takes over the same spot. Hidden while zoomed
                // or when the lesson panel is open.
                if scale <= 1.001 && !showLesson {
                    lessonOverlay(rect: rect, originX: originX, originY: originY, container: geo.size)
                }

                if showLesson { lessonPanel }
            }
            .task {
                if !loaded {
                    boxes = await BookStore.wordBoxes(for: pageURL); loaded = true
                }
                if fullText.isEmpty {
                    let t = await BookStore.ocrText(for: pageURL)
                    let lang = Self.detectLanguage(t)
                    await MainActor.run { fullText = t; language = lang }
                }
                if pageTrans == nil {
                    let t = await BookStore.translation(for: pageURL)
                    await MainActor.run {
                        if let t { pageTrans = (t.english, t.chinese) }
                        transTried = true
                    }
                }
            }
            .onDisappear { speaker.stop() }
        }
    }

    // MARK: draggable + shrinkable floating panels

    /// Wraps a floating panel so it can be dragged (grip bar) and shrunk/grown
    /// (the −/+ buttons, or a two-finger pinch). Double-tap the grip resets it.
    @ViewBuilder private func movablePanel<C: View>(_ move: Binding<Movable>,
                                                    @ViewBuilder content: () -> C) -> some View {
        VStack(spacing: 6) {
            gripBar(move)
            content()
        }
        .scaleEffect(move.wrappedValue.scale, anchor: .top)
        .offset(move.wrappedValue.offset)
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { v in move.wrappedValue.scale = min(1.5, max(0.5, move.wrappedValue.lastScale * v)) }
                .onEnded { _ in move.wrappedValue.lastScale = move.wrappedValue.scale }
        )
        // Long-press ANYWHERE on the box, then drag to move it. Buttons/scroll
        // inside still work (a quick tap never trips the 0.3s press).
        .simultaneousGesture(longPressDrag(move))
    }

    private func longPressDrag(_ move: Binding<Movable>) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture())
            .onChanged { value in
                if case .second(true, let drag?) = value {
                    move.wrappedValue.offset = CGSize(
                        width: move.wrappedValue.lastOffset.width + drag.translation.width,
                        height: move.wrappedValue.lastOffset.height + drag.translation.height)
                }
            }
            .onEnded { value in
                if case .second(true, _) = value {
                    move.wrappedValue.lastOffset = move.wrappedValue.offset
                }
            }
    }

    private func gripBar(_ move: Binding<Movable>) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.ultraThinMaterial)
            HStack {
                Button { stepScale(move, -0.15) } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 15)).foregroundStyle(theme.textSecondary)
                }.buttonStyle(.plain)
                Spacer()
                Capsule().fill(theme.textMuted.opacity(0.5)).frame(width: 44, height: 5)
                Spacer()
                Button { stepScale(move, 0.15) } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 15)).foregroundStyle(theme.textSecondary)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 30)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { v in
                    move.wrappedValue.offset = CGSize(
                        width: move.wrappedValue.lastOffset.width + v.translation.width,
                        height: move.wrappedValue.lastOffset.height + v.translation.height)
                }
                .onEnded { _ in move.wrappedValue.lastOffset = move.wrappedValue.offset }
        )
        .onTapGesture(count: 2) {
            withAnimation(.easeInOut(duration: 0.2)) { move.wrappedValue = Movable() }
        }
    }

    private func stepScale(_ move: Binding<Movable>, _ d: CGFloat) {
        withAnimation(.easeInOut(duration: 0.15)) {
            let s = min(1.5, max(0.5, move.wrappedValue.scale + d))
            move.wrappedValue.scale = s
            move.wrappedValue.lastScale = s
        }
    }

    private func pillButton(playing: Bool, icon: String, title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: playing ? "stop.circle.fill" : icon)
                Text(title)
            }
            .font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.black.opacity(0.45), in: Capsule())
        }.buttonStyle(.plain)
    }

    // MARK: 小课 — a word-by-word lesson with voice-over

    private func openLesson() {
        if showLesson { withAnimation { showLesson = false }; return }
        withAnimation { showLesson = true }
        if lesson == nil, !lessonLoading {
            lessonLoading = true
            Task {
                let l = await BookStore.lesson(for: pageURL)
                await MainActor.run { lesson = l; lessonLoading = false }
            }
        }
    }

    private var lessonPanel: some View {
        movablePanel($lessonMove) { lessonCard }
            .frame(maxWidth: 520)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var lessonCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 10) {
                Text("小课").font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.textPrimary)
                if let lesson, !lesson.isEmpty {
                    Button { playLesson(lesson) } label: {
                        Image(systemName: speaker.speakingId == "lesson" ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 22)).foregroundStyle(theme.accentText)
                    }.buttonStyle(.plain)
                }
                if lesson != nil {
                    Button { regenerateLesson() } label: {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.system(size: 20)).foregroundStyle(theme.textSecondary)
                    }.buttonStyle(.plain).accessibilityLabel("用当前风格重新备课")
                }
                Spacer()
                Button { withAnimation { showLesson = false }; speaker.stop() } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 22)).foregroundStyle(theme.textMuted.opacity(0.7))
                }.buttonStyle(.plain)
            }
            if lessonLoading || (lesson == nil && WordStudy.isAvailable) {
                HStack(spacing: 10) { ProgressView(); Text("正在备课…")
                    .font(.system(size: 14)).foregroundStyle(theme.textSecondary) }
            } else if let lesson, !lesson.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        ForEach(Array(lesson.enumerated()), id: \.offset) { _, step in
                            lessonStepRow(step)
                        }
                    }
                }
            } else {
                Text("这一页的小课需要本机的语言模型（真机上、开启 Apple Intelligence 时）。")
                    .font(.system(size: 14)).lineSpacing(4).foregroundStyle(theme.textSecondary)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: 340)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func lessonStepRow(_ step: LessonStep) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(step.word).font(.system(size: 18, weight: .semibold)).foregroundStyle(theme.accentText)
                Button { speaker.toggle(id: "ls-\(step.word)", text: step.word, language: language) } label: {
                    Image(systemName: "play.circle").font(.system(size: 15)).foregroundStyle(theme.accentText)
                }.buttonStyle(.plain)
            }
            Text(step.english).font(.system(size: 14)).foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(step.chinese).font(.system(size: 14)).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func regenerateLesson() {
        speaker.stop()
        BookStore.forgetGenerated(for: pageURL)
        lesson = nil; pageTrans = nil; lessonLoading = true
        Task {
            let l = await BookStore.lesson(for: pageURL)
            await MainActor.run { lesson = l; lessonLoading = false }
        }
    }

    private func playLesson(_ steps: [LessonStep]) {
        if speaker.speakingId == "lesson" { speaker.stop(); return }
        var segs: [(text: String, language: String?)] = []
        for s in steps {
            segs.append((s.word, language))
            segs.append((s.english, "en-US"))
            segs.append((s.chinese, "zh-CN"))
        }
        speaker.speakSequence(id: "lesson", segments: segs)
    }

    // MARK: the lesson in white space

    @ViewBuilder private func lessonOverlay(rect: CGRect, originX: CGFloat, originY: CGFloat,
                                            container: CGSize) -> some View {
        // Find the taller word-free band (above vs below the text block) and drop
        // the panel there so it starts off no word; drag/shrink from there.
        let band = whiteBand(rect: rect, originY: originY, container: container)
        let y = min(max(band, 120), container.height - 120)   // keep the panel on-screen
        movablePanel($cardMove) {
            if let selected { card(for: selected) }
            else if let pageTrans { translationPanel(pageTrans) }
            else { translationStatus }
        }
        .frame(maxWidth: min(container.width - 24, 460))
        .position(x: container.width / 2, y: y)
    }

    /// Shown in place of the page translation while it's still generating or when
    /// no model is available — so the panel is never silently empty.
    private var translationStatus: some View {
        HStack(spacing: 10) {
            if !transTried {
                ProgressView()
                Text("正在翻译整页…").font(.system(size: 14)).foregroundStyle(theme.textSecondary)
            } else {
                Image(systemName: "character.book.closed").foregroundStyle(theme.textMuted)
                Text(Translator.isAvailable
                     ? "这一页没有能翻译的文字。"
                     : "整页翻译需要本机语言模型（开启 Apple Intelligence），或在设置里填一个云端地址。")
                    .font(.system(size: 13)).lineSpacing(3).foregroundStyle(theme.textSecondary)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// The y-center (screen space) of the largest word-free horizontal band.
    private func whiteBand(rect: CGRect, originY: CGFloat, container: CGSize) -> CGFloat {
        guard !boxes.isEmpty else { return container.height - 120 }
        // Text block extent in screen Y (flip Vision's bottom-left origin).
        var topY = CGFloat.greatestFiniteMagnitude, botY: CGFloat = 0
        for b in boxes {
            let t = originY + CGFloat(1 - (b.y + b.h)) * rect.height
            let bo = originY + CGFloat(1 - b.y) * rect.height
            topY = min(topY, t); botY = max(botY, bo)
        }
        let gapBelow = container.height - botY
        let gapAbove = topY
        if gapBelow >= gapAbove { return botY + gapBelow / 2 }
        return topY - gapAbove / 2
    }

    private func translationPanel(_ t: (en: String, zh: String)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            transLine("English", t.en, id: "p-en", lang: "en-US")
            transLine("中文", t.zh, id: "p-zh", lang: "zh-CN")
        }
        .padding(Spacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func transLine(_ label: String, _ value: String, id: String, lang: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Button { speaker.toggle(id: id, text: value, language: lang) } label: {
                Image(systemName: speaker.speakingId == id ? "stop.circle.fill" : "play.circle")
                    .font(.system(size: 15)).foregroundStyle(theme.accentText)
            }.buttonStyle(.plain).padding(.top, 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(theme.textMuted)
                Text(value).font(.system(size: 14)).lineSpacing(2)
                    .foregroundStyle(theme.textPrimary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: word regions + card

    private func wordRegion(_ box: WordBox, in size: CGSize) -> some View {
        let key = Self.clean(box.text)
        let w = box.w * size.width, h = box.h * size.height
        let cx = (box.x + box.w / 2) * size.width
        let cy = (1 - (box.y + box.h / 2)) * size.height
        let isSel = selected == key && !key.isEmpty
        return RoundedRectangle(cornerRadius: 3)
            .fill(isSel ? theme.accent.opacity(0.40) : Color.yellow.opacity(0.28))
            .overlay(RoundedRectangle(cornerRadius: 3)
                .stroke(isSel ? theme.accentText.opacity(0.9) : theme.accentText.opacity(0.40),
                        lineWidth: isSel ? 1.5 : 0.75))
            .frame(width: max(w, 8), height: max(h, 8))
            .contentShape(Rectangle())
            .onTapGesture {
                guard !key.isEmpty else { return }
                withAnimation(.easeOut(duration: 0.2)) { selected = key }
                if cards[key] == nil {
                    let ctx = sentenceContext(for: box.text)
                    Task { await explain(key, line: ctx) }
                }
            }
            .position(x: cx, y: cy)
    }

    @ViewBuilder private func card(for word: String) -> some View {
        let c = cards[word]
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 8) {
                Text(word).font(.system(size: 22, weight: .semibold)).foregroundStyle(theme.textPrimary)
                Button { speaker.toggle(id: "w-\(word)", text: word, language: language) } label: {
                    Image(systemName: speaker.speakingId == "w-\(word)" ? "stop.circle.fill" : "play.circle")
                        .font(.system(size: 17)).foregroundStyle(theme.accentText)
                }.buttonStyle(.plain)
                Spacer()
                Button { withAnimation(.easeOut(duration: 0.2)) { selected = nil } } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 20)).foregroundStyle(theme.textMuted.opacity(0.7))
                }.buttonStyle(.plain)
            }
            if let c {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    row("English", c.english); row("中文", c.chinese)
                    row("语法", c.grammar); row("用法", c.usage)
                    playableRow("例句", c.example, id: "ex-\(word)")   // French → tap to hear
                }
            } else if WordStudy.isAvailable {
                HStack(spacing: 10) { ProgressView(); Text("正在想…")
                    .font(.system(size: 14)).foregroundStyle(theme.textSecondary) }
            } else {
                Text("这个词的解释需要本机的语言模型（开启 Apple Intelligence），或在设置里填一个云端地址。")
                    .font(.system(size: 14)).lineSpacing(4).foregroundStyle(theme.textSecondary)
            }
        }
        .padding(Spacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(theme.textMuted)
            Text(value.isEmpty ? "—" : value).font(.system(size: 16)).lineSpacing(3)
                .foregroundStyle(theme.textPrimary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A row whose value can be read aloud in the page's own language (e.g. the
    /// French example) — the extract the word/example is in, spoken.
    private func playableRow(_ label: String, _ value: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(theme.textMuted)
            HStack(alignment: .top, spacing: 6) {
                Button { speaker.toggle(id: id, text: value, language: language) } label: {
                    Image(systemName: speaker.speakingId == id ? "stop.circle.fill" : "play.circle")
                        .font(.system(size: 16)).foregroundStyle(theme.accentText)
                }.buttonStyle(.plain).padding(.top, 1)
                    .opacity(value.isEmpty ? 0 : 1)
                Text(value.isEmpty ? "—" : value).font(.system(size: 16)).lineSpacing(3)
                    .foregroundStyle(theme.textPrimary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: gestures + work

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { v in scale = min(6, max(1, lastScale * v)) }
            .onEnded { _ in lastScale = scale; if scale <= 1.001 { resetZoom() } }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { v in
                offset = CGSize(width: lastOffset.width + v.translation.width,
                                height: lastOffset.height + v.translation.height)
            }
            .onEnded { _ in lastOffset = offset }
    }

    private func resetZoom() { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }

    private func explain(_ word: String, line: String) async {
        if let card = await WordStudy.base(for: word, context: line) {
            await MainActor.run { cards[word] = card }
        }
    }

    /// The sentence around `word`, taken from the page's detected text, so the
    /// card explains the word *in context* rather than in isolation. Falls back
    /// to the whole page (or the word itself) when we can't isolate a sentence.
    private func sentenceContext(for word: String) -> String {
        let w = Self.clean(word)
        guard !fullText.isEmpty, !w.isEmpty else { return word }
        let sentences = fullText.components(separatedBy: CharacterSet(charactersIn: ".!?。！？…\n"))
        if let s = sentences.first(where: { $0.range(of: w, options: .caseInsensitive) != nil }) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        return fullText
    }

    private func fittedRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return CGRect(origin: .zero, size: container) }
        let s = min(container.width / imageSize.width, container.height / imageSize.height)
        return CGRect(origin: .zero, size: CGSize(width: imageSize.width * s, height: imageSize.height * s))
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
#endif
