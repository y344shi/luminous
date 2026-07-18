//
//  StudyReaderView.swift
//  Luminous — 逐字读: read a scanned page word by word.
//
//  Phase A of WORD-STUDY-PLAN.md. Opens from a 扫书 page: OCR the image (Vision),
//  lay the recognized words out as tappable chips, and tap one to raise a bottom
//  card with its base meaning (EN + 中文, grammar, usage, example) from the
//  on-device model. Cached in memory this session; persistence + the two-axis
//  deepening (breadth ↓ / depth →) + dwell-adaptive length + review come next.
//

import SwiftUI

struct StudyReaderView: View {
    let imageData: Data

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var lines: [[String]] = []      // words per OCR line
    @State private var phase: Phase = .reading
    @State private var picked: Picked?
    @State private var cards: [String: WordCard] = [:]   // session cache, keyed by cleaned word

    private enum Phase { case reading, ready, empty, failed }
    private struct Picked: Identifiable { let id: String }   // id == cleaned word

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("点一个词，看它的意思。")
                        .font(.system(size: 13)).foregroundStyle(theme.textSecondary)
                    switch phase {
                    case .reading:
                        HStack(spacing: 10) { ProgressView(); Text("正在读这一页…")
                            .font(.system(size: 14)).foregroundStyle(theme.textSecondary) }
                            .padding(.top, 20)
                    case .empty:
                        note("这一页没认出文字。")
                    case .failed:
                        note("这一页读取失败了。")
                    case .ready:
                        pageText
                    }
                }
                .padding(Spacing.lg)
            }
            .themedScreen()
            .navigationTitle("逐字读")
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
            }
            .task { await load() }
            .sheet(item: $picked) { p in cardSheet(for: p.id) }
        }
    }

    // MARK: the page as tappable words

    private var pageText: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                FlowLayout(spacing: 6) {
                    ForEach(Array(line.enumerated()), id: \.offset) { _, token in
                        wordChip(token)
                    }
                }
            }
        }
    }

    private func wordChip(_ token: String) -> some View {
        let key = Self.clean(token)
        return Button {
            guard !key.isEmpty else { return }
            picked = Picked(id: key)
            if cards[key] == nil { Task { await explain(key) } }
        } label: {
            Text(token)
                .font(.system(size: 19)).lineSpacing(4)
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 3).padding(.vertical, 1)
                .background(cards[key] != nil ? theme.accentSoft : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .disabled(key.isEmpty)
    }

    // MARK: the bottom card

    @ViewBuilder private func cardSheet(for word: String) -> some View {
        let card = cards[word]
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(word)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
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
                    Text("这个词的解释需要本机的语言模型（在真机上、开启 Apple Intelligence 时可用）。现在先记住它的样子。")
                        .font(.system(size: 14)).lineSpacing(4)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        #if os(iOS)
        .presentationDetents([.height(300), .large])
        .presentationBackground(.regularMaterial)
        #else
        .frame(minWidth: 360, minHeight: 300)
        #endif
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(theme.textMuted)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 16)).lineSpacing(3)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func note(_ s: String) -> some View {
        Text(s).font(.system(size: 14)).foregroundStyle(theme.textMuted).padding(.top, 16)
    }

    // MARK: work

    private func load() async {
        guard phase == .reading else { return }
        guard let (cg, orientation) = ImageInput.load(imageData) else {
            phase = .failed; return
        }
        let text = (try? await VisionOCR.recognize(cg, orientation: orientation)) ?? ""
        var rows: [[String]] = []
        for rawLine in text.split(separator: "\n") {
            let words = rawLine.split(separator: " ").map(String.init)
            if !words.isEmpty { rows.append(words) }
        }
        let result = rows
        await MainActor.run {
            lines = result
            phase = result.isEmpty ? .empty : .ready
        }
    }

    private func explain(_ word: String) async {
        // `word` is already cleaned; pass its line as context.
        let context = lines.first(where: { $0.map(Self.clean).contains(word) })?
            .joined(separator: " ") ?? word
        if let card = await WordStudy.base(for: word, context: context) {
            await MainActor.run { cards[word] = card }
        }
    }

    /// Strip surrounding punctuation/quotes; keep letters, digits, inner apostrophes/hyphens.
    private static func clean(_ token: String) -> String {
        token.trimmingCharacters(in: CharacterSet.alphanumerics.inverted
            .subtracting(CharacterSet(charactersIn: "'’-")))
            .trimmingCharacters(in: CharacterSet(charactersIn: "'’-"))
    }
}
