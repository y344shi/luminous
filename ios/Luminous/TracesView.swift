//
//  TracesView.swift
//  Luminous
//
//  The "痕迹" tab — the warm journal of moments you were really present.
//  Ported from components/trace/TraceJournal.tsx.
//

import SwiftUI

struct TracesView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme

    @State private var editingId: String?
    @State private var draftText = ""
    @State private var pendingDelete: DailyTrace?

    // Group traces by date, newest first.
    private var grouped: [(date: String, traces: [DailyTrace])] {
        let keys = Array(NSOrderedSet(array: store.traces.map { $0.date })) as? [String] ?? []
        return keys.map { key in
            (key, store.traces.filter { $0.date == key })
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    PageHeader(title: Copy.Traces.title, subtitle: Copy.Traces.subtitle)

                    WeekReviewCard()

                    if store.traces.isEmpty {
                        EmptyState(icon: "🕯️", text: Copy.Traces.empty)
                    } else {
                        ForEach(grouped, id: \.date) { group in
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text(DomainUtil.friendlyDate(group.date))
                                    .font(.system(size: 13))
                                    .foregroundStyle(theme.textMuted)
                                ForEach(group.traces) { trace in
                                    traceCard(trace)
                                }
                            }
                        }
                    }
                }
                .padding(Spacing.lg)
            }
            .themedScreen()
            .navigationTitle(Copy.Tab.traces)
            .inlineNavTitle()
            .confirmationDialog(
                Copy.Traces.deleteTitle,
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button(Copy.Traces.deleteYes, role: .destructive) {
                    if let t = pendingDelete { store.removeTrace(t.id) }
                    pendingDelete = nil
                }
                Button(Copy.Traces.deleteNo, role: .cancel) { pendingDelete = nil }
            } message: {
                Text(Copy.Traces.deleteBody)
            }
        }
    }

    /// A trace still carrying only the app's gentle default line (not the
    /// person's own words). Detected by the warm prefix the generator uses, so
    /// no schema flag is needed and old traces are handled too.
    private func isGenerated(_ t: DailyTrace) -> Bool {
        t.text.hasPrefix(Copy.tracePrefix) || t.text == Copy.Completion.skippedMsg
    }

    private func traceCard(_ trace: DailyTrace) -> some View {
        BreathingCard {
            if editingId == trace.id {
                VStack(spacing: Spacing.sm) {
                    ZStack(alignment: .topLeading) {
                        if draftText.isEmpty {
                            Text("写一句你自己做了什么…")
                                .font(.system(size: 16))
                                .foregroundStyle(theme.textMuted)
                                .padding(.horizontal, 13).padding(.vertical, 16)
                        }
                        TextEditor(text: $draftText)
                            .font(.system(size: 16))
                            .frame(minHeight: 90)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                    }
                    .background(theme.surfaceSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    // Offer the app's gentle line as a fallback, never as the default.
                    if isGenerated(trace) {
                        Button {
                            draftText = trace.text
                        } label: {
                            Text("或者用这句：\(trace.text)")
                                .font(.system(size: 12)).lineSpacing(2)
                                .foregroundStyle(theme.textMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                    HStack(spacing: Spacing.sm) {
                        SoftButton(title: Copy.Traces.editSave, enabled: !draftText.trimmed.isEmpty) {
                            store.updateTrace(trace.id, text: draftText.trimmed)
                            editingId = nil
                        }
                        SoftButton(title: "取消", variant: .ghost) { editingId = nil }
                    }
                }
            } else {
                let generated = isGenerated(trace)
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(trace.text)
                        .font(.system(size: 16)).lineSpacing(4)
                        // The app's default line reads as a soft suggestion;
                        // the person's own words read as the record.
                        .foregroundStyle(generated ? theme.textSecondary : theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Spacing.md) {
                        Button(generated ? "写一句你自己的" : Copy.Traces.edit) {
                            // Generated → invite fresh words (empty); own words → edit them.
                            draftText = generated ? "" : trace.text
                            editingId = trace.id
                        }
                        .font(.system(size: 13, weight: generated ? .medium : .regular))
                        .tint(generated ? theme.accentText : theme.textSecondary)
                        Spacer()
                        Button {
                            pendingDelete = trace
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                        }
                        .tint(theme.textMuted)
                    }
                }
            }
        }
    }
}
