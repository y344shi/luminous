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
                .gesture(zoomGesture)
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
                if pageTrans == nil, let t = await BookStore.translation(for: pageURL) {
                    await MainActor.run { pageTrans = (t.english, t.chinese) }
                }
            }
            .onDisappear { speaker.stop() }
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 10) {
                Text("小课").font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.textPrimary)
                if let lesson, !lesson.isEmpty {
                    Button { playLesson(lesson) } label: {
                        Image(systemName: speaker.speakingId == "lesson" ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 22)).foregroundStyle(theme.accentText)
                    }.buttonStyle(.plain)
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
        .padding(Spacing.md)
        .frame(maxHeight: .infinity, alignment: .bottom)
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
        let panel = Group {
            if let selected { card(for: selected) }
            else if let pageTrans { translationPanel(pageTrans) }
        }
        // Find the taller word-free band (above vs below the text block) and drop
        // the panel there so it never sits on any word.
        let band = whiteBand(rect: rect, originY: originY, container: container)
        panel
            .frame(maxWidth: min(container.width - 24, 460))
            .position(x: container.width / 2, y: band)
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
                if cards[key] == nil { Task { await explain(key, line: box.text) } }
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
                row("English", c.english); row("中文", c.chinese)
                row("语法", c.grammar); row("用法", c.usage); row("例句", c.example)
            } else if WordStudy.isAvailable {
                HStack(spacing: 10) { ProgressView(); Text("正在想…")
                    .font(.system(size: 14)).foregroundStyle(theme.textSecondary) }
            } else {
                Text("这个词的解释需要本机的语言模型（真机上、开启 Apple Intelligence 时）。")
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

    // MARK: gestures + work

    private var zoomGesture: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { v in scale = min(6, max(1, lastScale * v)) }
                .onEnded { _ in lastScale = scale; if scale <= 1.001 { resetZoom() } },
            DragGesture()
                .onChanged { v in
                    guard scale > 1 else { return }     // at 1× let the pager swipe
                    offset = CGSize(width: lastOffset.width + v.translation.width,
                                    height: lastOffset.height + v.translation.height)
                }
                .onEnded { _ in lastOffset = offset }
        )
    }

    private func resetZoom() { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }

    private func explain(_ word: String, line: String) async {
        if let card = await WordStudy.base(for: word, context: line) {
            await MainActor.run { cards[word] = card }
        }
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
