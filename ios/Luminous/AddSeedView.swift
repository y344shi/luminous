//
//  AddSeedView.swift
//  Luminous
//
//  Catch a soft wish: text → mock parse → preview → save.
//  Ported from components/seed/AddSeedFlow.tsx.
//

import SwiftUI

struct AddSeedView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @Binding var path: NavigationPath

    @State private var text = ""
    @State private var draft: SeedDraft?
    @State private var saving = false
    @State private var parsing = false
    @State private var chosenTags: [String] = []
    @State private var customTag = ""
    /// A merge the model suggests — always CONFIRMED by the user, never silent.
    @State private var mergeOffer: (id: String, title: String, draft: SeedDraft)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if let draft = draft {
                    preview(draft)
                } else {
                    input
                }
            }
            .padding(Spacing.lg)
        }
        .themedScreen()
        .navigationTitle(Copy.Home.addSeed)
        .inlineNavTitle()
        .confirmationDialog(
            "这好像是「\(mergeOffer?.title ?? "")」的延续",
            isPresented: Binding(get: { mergeOffer != nil },
                                 set: { if !$0 { mergeOffer = nil } }),
            titleVisibility: .visible
        ) {
            Button("并进去，记在一起") {
                if let offer = mergeOffer {
                    store.mergeLearningSeed(newRaw: text, into: offer.id)
                }
                mergeOffer = nil
                path.removeLast(path.count)
            }
            Button("种一颗新的") {
                if let offer = mergeOffer {
                    store.addSeed(SeedParser.draftToSeed(offer.draft))
                }
                mergeOffer = nil
                path.removeLast(path.count)
            }
            Button("再想想", role: .cancel) { mergeOffer = nil }
        } message: {
            Text("并进去：新想法记到它的手帐里，愿望不重复。种新的：作为独立的愿望出现在花园里。")
        }
    }

    private var input: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(Copy.Add.inputLabel)
                .font(.system(size: 15))
                .foregroundStyle(theme.textPrimary)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(Copy.Add.placeholder)
                        .font(.system(size: 16)).lineSpacing(4)
                        .foregroundStyle(theme.textMuted)
                        .padding(.horizontal, 13).padding(.vertical, 16)
                }
                TextEditor(text: $text)
                    .font(.system(size: 16))
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                    .padding(8)
            }
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(theme.border, lineWidth: 1))

            SoftButton(title: parsing ? "轻轻接住…" : Copy.Add.catchIt,
                       enabled: !text.trimmed.isEmpty && !parsing) {
                parsing = true
                Task {
                    // On-device model reads the wish; keyword net is the fallback.
                    let parsed = await AISeedParser.parse(text)
                    await MainActor.run {
                        draft = parsed
                        chosenTags = parsed.tags        // suggested set, pre-chosen
                        parsing = false
                    }
                }
            }
        }
    }

    private func preview(_ draft: SeedDraft) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(Copy.Add.caught)
                .font(.system(size: 14))
                .foregroundStyle(theme.textMuted)

            BreathingCard {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text(draft.title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)

                    FlowLayout(spacing: Spacing.xs) {
                        ForEach(draft.categories, id: \.self) { cat in
                            if let meta = Meta.category[cat] {
                                tag("\(meta.emoji) \(meta.label)")
                            }
                        }
                        tag(Meta.durationLabel(draft.estimatedDurationMin))
                        tag(Meta.energyLabel[draft.energyRequired] ?? "")
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(Copy.Add.minLabel)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textMuted)
                        Text(draft.minimumAction)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    tagEditor(draft)
                }
            }

            SoftButton(title: saving ? "整理中…" : Copy.Add.save, enabled: !saving) {
                save(draft)
            }
            HStack(spacing: Spacing.sm) {
                SoftButton(title: Copy.Add.edit, variant: .soft) { self.draft = nil }
                SoftButton(title: Copy.Add.again, variant: .ghost) {
                    text = ""; self.draft = nil
                }
            }
        }
    }

    /// Save the caught wish. If it continues a pursuit you're already carrying
    /// (same language, or — per the on-device model — the same long-term thing),
    /// merge into that anchor instead of spawning a duplicate, so the history
    /// stays in one place. The LLM judges; keyword language-match is the
    /// fallback; when unsure it always plants fresh.
    private func save(_ draft: SeedDraft) {
        var draft = draft
        draft.tags = chosenTags                      // the user's edited tag set

        // Merge is offered ONLY for learning pursuits (where "the same long-term
        // thing" is unambiguous). Anything else always plants fresh — a saved
        // wish must never silently vanish into an old one.
        let isLearning = LearningTopic.language(ofTitle: draft.title) != nil
            || draft.categories.contains(.learning)
        let candidates = isLearning
            ? store.learningSeeds.map { (id: $0.id, title: $0.title) }
            : []
        guard !candidates.isEmpty else {
            store.addSeed(SeedParser.draftToSeed(draft))
            path.removeLast(path.count)
            return
        }
        saving = true
        Task { [draft] in
            // The model gets 6 seconds to say "this continues an old pursuit";
            // silence, errors, or timeout all mean: plant fresh. Saving can
            // never hang and never lose the wish.
            let target: String? = await withTaskGroup(of: String??.self) { group in
                group.addTask {
                    await LearningMerge.mergeTarget(newTitle: draft.title,
                                                    candidates: candidates)
                }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 6_000_000_000)
                    return String??.some(nil)
                }
                let first = await group.next() ?? nil
                group.cancelAll()
                return first ?? nil
            }
            await MainActor.run {
                saving = false
                // Never merge silently: a saved wish quietly vanishing into an
                // old one reads as data loss. The model may only SUGGEST.
                if let target, let anchor = store.findSeed(target) {
                    mergeOffer = (target, anchor.title, draft)
                } else {
                    store.addSeed(SeedParser.draftToSeed(draft))
                    path.removeLast(path.count)
                }
            }
        }
    }

    // MARK: 标签 — suggested chips to toggle, plus the user's own; at most 5.

    private func tagEditor(_ draft: SeedDraft) -> some View {
        // chosen chips first, then remaining suggestions (cleaned, deduped)
        let pool = (draft.tags
                    + TagSuggest.suggest(title: draft.title, categories: draft.categories))
            .compactMap(TagSuggest.clean)
        var display = chosenTags
        for t in pool where !display.contains(t) { display.append(t) }
        let full = chosenTags.count >= TagSuggest.maxTags
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("标签")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textMuted)
                Spacer()
                Text("\(chosenTags.count)/\(TagSuggest.maxTags)")
                    .font(.system(size: 11))
                    .foregroundStyle(full ? theme.accentText : theme.textMuted)
            }
            FlowLayout(spacing: Spacing.xs) {
                // every known tag (chosen ∪ suggested) is a toggle chip
                ForEach(display, id: \.self) { t in
                    tagChip(t)
                }
            }
            HStack(spacing: Spacing.sm) {
                TextField("自己写一个…", text: $customTag)
                    .font(.system(size: 13))
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(theme.surfaceSoft)
                    .clipShape(Capsule())
                    .onSubmit { addCustomTag() }
                Button { addCustomTag() } label: {
                    Text("加上")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(theme.accentSoft)
                        .foregroundStyle(theme.accentText)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(full || TagSuggest.clean(customTag) == nil)
            }
            if full {
                Text("五个刚刚好，多了就吵了。")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textMuted)
            }
        }
    }

    private func tagChip(_ t: String) -> some View {
        let on = chosenTags.contains(t)
        return Button {
            if on {
                chosenTags.removeAll { $0 == t }
            } else if chosenTags.count < TagSuggest.maxTags {
                chosenTags.append(t)
            }
        } label: {
            Text(t)
                .font(.system(size: 12, weight: on ? .medium : .regular))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(on ? theme.accentSoft : theme.surfaceSoft)
                .foregroundStyle(on ? theme.accentText : theme.textSecondary)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(on ? theme.accent.opacity(0.5) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .opacity(!on && chosenTags.count >= TagSuggest.maxTags ? 0.45 : 1)
    }

    private func addCustomTag() {
        guard let t = TagSuggest.clean(customTag),
              chosenTags.count < TagSuggest.maxTags,
              !chosenTags.contains(t) else { return }
        chosenTags.append(t)
        customTag = ""
    }

    private func tag(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 12))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .foregroundStyle(theme.textMuted)
            .background(theme.surfaceSoft)
            .clipShape(Capsule())
    }
}
