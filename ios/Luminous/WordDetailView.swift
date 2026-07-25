//
//  WordDetailView.swift
//  Luminous — tap a word (e.g. in the book's vocabulary) to see everything about it.
//
//  Pulls together the model's meaning (English + 中文) and the real dictionary
//  reference (definition + phonetic online, a Tatoeba example sentence with
//  translation, and Apple's offline Oxford dictionary panel). Degrades gracefully
//  when a source is offline / has nothing.
//

import SwiftUI

/// A word to open in the detail sheet (Identifiable so it drives `.sheet(item:)`).
struct WordSelection: Identifiable { let id = UUID(); let word: String; let language: String? }

struct WordDetailView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let word: String
    let language: String?

    @State private var card: WordCard?
    @State private var ref: WordRef?
    @State private var loadingCard = true
    @State private var loadingRef = true
    #if os(iOS)
    @State private var dictTerm: DictTerm?
    #endif
    @State private var speaker = Speaker()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    header
                    meaningBlock
                    referenceBlock
                    Divider().padding(.vertical, 2)
                    DeepenSection(topic: word, language: language) { shownSoFar }
                }
                .padding(Spacing.lg)
            }
            .themedScreen()
            .navigationTitle(word)
            .inlineNavTitle()
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) { Button("完成") { dismiss() } }
                #endif
            }
            .task { await load() }
            .onDisappear { speaker.stop() }
            #if os(iOS)
            .sheet(item: $dictTerm) { t in DictionaryPanel(term: t.word).ignoresSafeArea() }
            #endif
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(word).font(.system(size: 24, weight: .semibold)).foregroundStyle(theme.textPrimary)
            Button { speaker.toggle(id: "w", text: word, language: language) } label: {
                Image(systemName: speaker.speakingId == "w" ? "stop.circle.fill" : "play.circle")
                    .font(.system(size: 20)).foregroundStyle(theme.accentText)
            }.buttonStyle(.plain)
            if let ph = ref?.phonetic, !ph.isEmpty {
                Text(ph).font(.system(size: 14)).foregroundStyle(theme.textSecondary)
            }
            Spacer()
            #if os(iOS)
            Button { dictTerm = DictTerm(word: word) } label: {
                Label("Oxford", systemImage: "character.book.closed")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(theme.accentText)
            }.buttonStyle(.plain)
            #endif
        }
    }

    @ViewBuilder private var meaningBlock: some View {
        if let c = card {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                row("English", c.english); row("中文", c.chinese)
                if !c.grammar.isEmpty { row("语法", c.grammar) }
                if !c.usage.isEmpty { row("用法", c.usage) }
                if !c.example.isEmpty { playableRow("例句", c.example, id: "ai-ex") }
            }
        } else if loadingCard {
            HStack(spacing: 10) { ProgressView(); Text("正在想…")
                .font(.system(size: 14)).foregroundStyle(theme.textSecondary) }
        }
    }

    @ViewBuilder private var referenceBlock: some View {
        Divider().padding(.vertical, 2)
        Text("词典").font(.system(size: 11, weight: .medium)).foregroundStyle(theme.textMuted)
        if let ref {
            VStack(alignment: .leading, spacing: 6) {
                if let def = ref.definition, !def.isEmpty {
                    Text((ref.partOfSpeech.map { "\($0) · " } ?? "") + def)
                        .font(.system(size: 15)).lineSpacing(3)
                        .foregroundStyle(theme.textPrimary).fixedSize(horizontal: false, vertical: true)
                }
                if let ex = ref.exampleText, !ex.isEmpty {
                    playableRowText("例句（真实语料）", ex, ref.exampleTranslation, id: "ref-ex")
                }
                if (ref.definition ?? "").isEmpty && (ref.exampleText ?? "").isEmpty {
                    dictionaryHint
                }
            }
        } else if loadingRef {
            HStack(spacing: 8) { ProgressView().controlSize(.small)
                Text("查词典…").font(.system(size: 12)).foregroundStyle(theme.textMuted) }
        } else {
            dictionaryHint
        }
    }

    private var dictionaryHint: some View {
        Text("这个词在网络词典里没查到（法语变位词常见）。点右上角 “Oxford” 用本机词典看，通常能查到。")
            .font(.system(size: 13)).lineSpacing(3).foregroundStyle(theme.textSecondary)
    }

    // MARK: rows

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(theme.textMuted)
            Text(value.isEmpty ? "—" : value).font(.system(size: 16)).lineSpacing(3)
                .foregroundStyle(theme.textPrimary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func playableRow(_ label: String, _ value: String, id: String) -> some View {
        playableRowText(label, value, nil, id: id)
    }

    private func playableRowText(_ label: String, _ value: String, _ sub: String?, id: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(theme.textMuted)
            HStack(alignment: .top, spacing: 6) {
                Button { speaker.toggle(id: id, text: value, language: language) } label: {
                    Image(systemName: speaker.speakingId == id ? "stop.circle.fill" : "play.circle")
                        .font(.system(size: 16)).foregroundStyle(theme.accentText)
                }.buttonStyle(.plain).padding(.top, 1)
                VStack(alignment: .leading, spacing: 1) {
                    Text(value).font(.system(size: 15)).lineSpacing(3)
                        .foregroundStyle(theme.textPrimary).fixedSize(horizontal: false, vertical: true)
                    if let sub, !sub.isEmpty {
                        Text(sub).font(.system(size: 13)).foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Everything already on screen, so "更多" doesn't repeat it.
    private var shownSoFar: String {
        var bits: [String] = []
        if let c = card {
            bits.append("英文：\(c.english)；中文：\(c.chinese)；语法：\(c.grammar)；用法：\(c.usage)；例句：\(c.example)")
        }
        if let r = ref {
            if let d = r.definition { bits.append("词典：\(d)") }
            if let e = r.exampleText { bits.append("例句：\(e)") }
        }
        return bits.joined(separator: "\n")
    }

    private func load() async {
        async let cardTask = WordStudy.base(for: word, context: word)
        async let refTask = WordReference.look(word, language: language)
        let c = await cardTask
        let r = await refTask
        await MainActor.run {
            card = c; loadingCard = false
            ref = r; loadingRef = false
        }
    }
}
