//
//  PageTextReader.swift
//  Luminous — 逐字读: read the words ON the photo.
//
//  A full-screen page: the scanned image, with every recognized word overlaid as
//  a tappable region (from Vision's per-word boxes). Tap a word on the page and
//  its explanation card rises from the bottom (EN + 中文 + 语法/用法/例句,
//  on-device). Pinch to zoom, double-tap to reset — the highlights ride the same
//  transform as the image, so they stay on their words. Opened by double-tapping
//  the page in the reader. iOS/iPadOS.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

struct PageTextReader: View {
    let pageURL: URL
    let image: UIImage
    var language: String?
    var onClose: () -> Void

    @Environment(\.theme) private var theme
    @State private var boxes: [WordBox] = []
    @State private var loaded = false
    @State private var selected: String?
    @State private var cards: [String: WordCard] = [:]
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var speaker = Speaker()

    var body: some View {
        GeometryReader { geo in
            let rect = fittedRect(imageSize: image.size, in: geo.size)
            ZStack {
                Color.black.ignoresSafeArea()

                ZStack(alignment: .topLeading) {
                    Image(uiImage: image).resizable()
                        .frame(width: rect.width, height: rect.height)
                    ForEach(Array(boxes.enumerated()), id: \.offset) { _, box in
                        wordRegion(box, in: rect.size)
                    }
                }
                .frame(width: rect.width, height: rect.height)
                .scaleEffect(scale).offset(offset)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                .gesture(zoomGesture)
                .onTapGesture(count: 2) { withAnimation(.easeInOut(duration: 0.2)) { resetZoom() } }

                VStack {
                    HStack {
                        Spacer()
                        Button { onClose() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28)).symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.4))
                        }.buttonStyle(.plain).padding()
                    }
                    Spacer()
                    if !loaded {
                        HStack(spacing: 10) { ProgressView().tint(.white)
                            Text("正在找出页面上的字…").font(.system(size: 13)).foregroundStyle(.white) }
                            .padding(.bottom, 30)
                    } else if boxes.isEmpty {
                        Text("这一页没认出可点的字。").font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.8)).padding(.bottom, 30)
                    }
                    if let selected { card(for: selected) }
                }
            }
            .task {
                if !loaded { boxes = await BookStore.wordBoxes(for: pageURL); loaded = true }
            }
            .onDisappear { speaker.stop() }
        }
    }

    // A tappable region sitting exactly on its word (Vision space → display space).
    private func wordRegion(_ box: WordBox, in size: CGSize) -> some View {
        let key = Self.clean(box.text)
        let w = box.w * size.width, h = box.h * size.height
        let cx = (box.x + box.w / 2) * size.width
        let cy = (1 - (box.y + box.h / 2)) * size.height     // flip Y
        let isSel = selected == key && !key.isEmpty
        return RoundedRectangle(cornerRadius: 3)
            .fill(isSel ? theme.accent.opacity(0.35) : Color.yellow.opacity(0.001))
            .overlay(RoundedRectangle(cornerRadius: 3)
                .stroke(isSel ? theme.accentText.opacity(0.8) : .clear, lineWidth: 1))
            .frame(width: max(w, 6), height: max(h, 6))
            .position(x: cx, y: cy)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !key.isEmpty else { return }
                withAnimation(.easeOut(duration: 0.2)) { selected = key }
                if cards[key] == nil { Task { await explain(key, line: box.text) } }
            }
    }

    // The explanation card.
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(Spacing.md)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(theme.textMuted)
            Text(value.isEmpty ? "—" : value).font(.system(size: 16)).lineSpacing(3)
                .foregroundStyle(theme.textPrimary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var zoomGesture: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { v in scale = min(6, max(1, lastScale * v)) }
                .onEnded { _ in lastScale = scale; if scale <= 1.001 { resetZoom() } },
            DragGesture()
                .onChanged { v in
                    guard scale > 1 else { return }
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

    private static func clean(_ token: String) -> String {
        token.trimmingCharacters(in: CharacterSet.alphanumerics.inverted
            .subtracting(CharacterSet(charactersIn: "'’-")))
            .trimmingCharacters(in: CharacterSet(charactersIn: "'’-"))
    }
}
#endif
