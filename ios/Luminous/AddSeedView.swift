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

            SoftButton(title: Copy.Add.catchIt, enabled: !text.trimmed.isEmpty) {
                draft = SeedParser.parse(text)
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
                }
            }

            SoftButton(title: Copy.Add.save) {
                store.addSeed(SeedParser.draftToSeed(draft))
                path.removeLast(path.count)
            }
            HStack(spacing: Spacing.sm) {
                SoftButton(title: Copy.Add.edit, variant: .soft) { self.draft = nil }
                SoftButton(title: Copy.Add.again, variant: .ghost) {
                    text = ""; self.draft = nil
                }
            }
        }
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
