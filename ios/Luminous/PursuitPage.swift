//
//  PursuitPage.swift
//  Luminous — every long-term pursuit gets a 手帐: a page where its thoughts live
//
//  Not a management board — no subtasks, no checkboxes-with-deadlines, no
//  progress %. A pursuit page holds: the ideas and notes you've dropped on it,
//  its lived history (done moments, learned things), and — on request — the
//  on-device model reading all of that to suggest where the pursuit could grow
//  next. Keeping a thought on the page also keeps the pursuit gently warm in
//  the ranking (Recurrence.engagedRecently).
//

import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Expansion suggestions (the model reads the page)

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenGrowth {
    @Guide(description: "一个可以让这件长期的事往前长一点的小活动，24 字以内，具体、现在这个阶段做得到")
    var idea: String
    @Guide(description: "为什么是现在、为什么是这一步，一句话")
    var why: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenGrowthSet {
    @Guide(description: "恰好三个方向不同的小活动", .count(3))
    var ideas: [GenGrowth]
}
#endif

// MARK: - The page

struct PursuitPageView: View {
    let seed: Seed

    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme

    @State private var draft = ""
    @State private var growing = false
    @State private var growth: [(idea: String, why: String)] = []
    @State private var showSketch = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("手帐 · 这件事的想法都放在这里")
                .font(.system(size: 14))
                .foregroundStyle(theme.textMuted)

            journeyLine
            notesDeck
            growthSection
        }
    }

    // MARK: the lived history, one soft line

    @ViewBuilder private var journeyLine: some View {
        let stats = store.seedHistory()[seed.id]
        let done = stats?.completions ?? 0
        let noteCount = store.notes(for: seed.id).count
        if done > 0 || noteCount > 0 {
            Text(journeyText(done: done, notes: noteCount))
                .font(.system(size: 12))
                .foregroundStyle(theme.textSecondary)
        }
    }

    private func journeyText(done: Int, notes: Int) -> String {
        var bits: [String] = []
        if done > 0 { bits.append("做过 \(done) 次") }
        if notes > 0 { bits.append("留下 \(notes) 条想法") }
        return "一路上：" + bits.joined(separator: " · ")
    }

    // MARK: notes — a click-through card deck (each thought is a card)

    @ViewBuilder private var notesDeck: some View {
        let _ = store.noteBump   // re-read when notes change
        let notes = store.notes(for: seed.id)
        #if os(iOS)
        TabView {
            ForEach(notes) { note in
                noteCard(note).padding(.horizontal, 4).padding(.bottom, 26)
            }
            addCard.padding(.horizontal, 4).padding(.bottom, 26)
        }
        .tabViewStyle(.page(indexDisplayMode: notes.isEmpty ? .never : .automatic))
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .frame(height: 224)
        #else
        // macOS has no .page style — a horizontal deck of the same cards.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.md) {
                ForEach(notes) { note in noteCard(note).frame(width: 300) }
                addCard.frame(width: 300)
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 200)
        #endif
    }

    private func noteGlyph(_ kind: PursuitNote.Kind) -> String {
        switch kind {
        case .aiIdea: return "sparkles"
        case .idea:   return "lightbulb"
        case .note:   return "leaf"
        case .sketch: return "hand.draw"
        }
    }

    /// A note's body — text for written notes, the drawing for a handwritten one.
    @ViewBuilder private func noteBody(_ note: PursuitNote) -> some View {
        if note.kind == .sketch {
            if let img = SketchNote.image(fromBase64: note.text) {
                img.resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 130, alignment: .leading)
            } else {
                Text("一张手写的便签")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.textSecondary)
            }
        } else {
            Text(note.text)
                .font(.system(size: 17)).lineSpacing(5)
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func noteCard(_ note: PursuitNote) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: noteGlyph(note.kind))
                    .font(.system(size: 13))
                    .foregroundStyle(theme.accent)
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { store.removeNote(note.id) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.textMuted.opacity(0.7))
                        .frame(width: 40, height: 40)   // a real finger target
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("删除这条想法")
            }
            noteBody(note)
            Spacer(minLength: 0)
            Text(DomainUtil.friendlyDate(note.dateKey))
                .font(.system(size: 11))
                .foregroundStyle(theme.textMuted)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(theme.border.opacity(0.6), lineWidth: 1))
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13)).foregroundStyle(theme.accent)
                Text("放一句想法")
                    .font(.system(size: 13)).foregroundStyle(theme.textMuted)
            }
            TextField("路过时想到什么…", text: $draft, axis: .vertical)
                .font(.system(size: 16)).lineSpacing(4)
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            HStack(spacing: Spacing.sm) {
                Button {
                    store.addNote(draft, to: seed.id, kind: .idea)
                    draft = ""
                } label: {
                    Text("记下")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(theme.accentSoft)
                        .foregroundStyle(theme.accentText)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                #if canImport(PencilKit) && os(iOS)
                if SketchNote.canDraw {
                    Button { showSketch = true } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "hand.draw").font(.system(size: 13))
                            Text("画一张").font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .foregroundStyle(theme.accentText)
                        .overlay(Capsule().strokeBorder(theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("手写一张便签")
                }
                #endif
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(theme.border, lineWidth: 1))
        #if canImport(PencilKit) && os(iOS)
        .sheet(isPresented: $showSketch) {
            SketchComposerSheet { base64 in
                store.addNote(base64, to: seed.id, kind: .sketch)
            }
        }
        #endif
    }

    // MARK: growth — the model reads the page and suggests where to grow

    @ViewBuilder private var growthSection: some View {
        if !growth.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("它可以往这些方向长一点：")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textMuted)
                ForEach(growth, id: \.idea) { g in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(g.idea)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
                        Text(g.why)
                            .font(.system(size: 12)).lineSpacing(2)
                            .foregroundStyle(theme.textSecondary)
                        Button {
                            store.addNote(g.idea, to: seed.id, kind: .aiIdea)
                            growth.removeAll { $0.idea == g.idea }
                        } label: {
                            Text("记到手帐里")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(theme.accentText)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surfaceSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        } else if AIHelper.isAvailable {
            Button { grow() } label: {
                HStack(spacing: 6) {
                    if growing { ProgressView().controlSize(.small) }
                    else { Image(systemName: "arrow.up.right.circle") }
                    Text(growing ? "在看这一路…" : "看看它可以往哪长")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(theme.surface)
                .foregroundStyle(theme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(growing)
        }
    }

    private func grow() {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        growing = true
        // Everything the page knows: notes, done count, learned things, traces.
        let notes = store.notes(for: seed.id).prefix(8).map(\.text)
        let stats = store.seedHistory()[seed.id]
        let lang = LearningTopic.language(ofTitle: seed.title)
        let learned = lang.map { store.learnedWords($0) } ?? []
        let traces = store.traces.filter { $0.seedId == seed.id }.prefix(5).map(\.text)
        Task { @MainActor in
            defer { growing = false }
            let instructions = """
            你在陪一个人照看一件长期的心愿。根据这件事一路留下的痕迹和想法，\
            提出恰好三个方向不同的小活动，让它自然地往前长一点。每个都要小、\
            具体、这个阶段就能做。不布置任务、不加期限、不评判进度。
            """
            var bits = ["心愿：「\(seed.title)」"]
            if let s = stats, s.completions > 0 { bits.append("已经做过 \(s.completions) 次") }
            if !notes.isEmpty { bits.append("页上的想法：\(notes.joined(separator: "；"))") }
            if !learned.isEmpty { bits.append("学过的词（部分）：\(learned.suffix(10).joined(separator: "、"))") }
            if !traces.isEmpty { bits.append("留下过的痕迹：\(traces.joined(separator: "；"))") }
            let prompt = bits.joined(separator: "。\n")
            guard let r = try? await LanguageModelSession(instructions: instructions)
                .respond(to: prompt, generating: GenGrowthSet.self) else { return }
            growth = r.content.ideas
                .filter { ForbiddenWords.passes($0.idea + $0.why) && !$0.idea.isEmpty }
                .map { (String($0.idea.prefix(24)), String($0.why.prefix(40))) }
        }
        #endif
    }
}
