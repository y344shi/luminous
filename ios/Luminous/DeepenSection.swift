//
//  DeepenSection.swift
//  Luminous — "再讲深一点": ask for more on anything the AI generated.
//
//  Drops under any generated explanation (a word card, a page lesson, the whole
//  book's lesson). Each tap asks for MORE without repeating what's already on
//  screen, and the rounds stack up so you can keep going as deep as you want.
//  Every round can be read aloud in the right voice per line.
//

import SwiftUI

struct DeepenSection: View {
    @Environment(\.theme) private var theme

    /// What we're going deeper on (a word, a page, the book's title).
    let topic: String
    /// The sentence / page it came from, when there is one.
    var context: String = ""
    /// The book's language, so examples are read in the right voice.
    var language: String? = nil
    /// Everything already shown, so the model doesn't repeat it. Read lazily so
    /// it always reflects the latest state (including earlier rounds).
    let alreadyShown: () -> String

    @State private var rounds: [String] = []
    @State private var loading = false
    @State private var failed: String?
    @State private var speaker = Speaker()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(Array(rounds.enumerated()), id: \.offset) { i, round in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("更多 · \(i + 1)")
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(theme.textMuted)
                        Button { speak(round, id: "deep-\(i)") } label: {
                            Image(systemName: speaker.speakingId == "deep-\(i)"
                                  ? "stop.circle.fill" : "speaker.wave.2")
                                .font(.system(size: 13)).foregroundStyle(theme.accentText)
                        }.buttonStyle(.plain)
                        Spacer()
                    }
                    Text(rendered(round))
                        .font(.system(size: 14)).lineSpacing(4)
                        .textSelection(.enabled)
                        .foregroundStyle(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surfaceSoft.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if loading {
                HStack(spacing: 8) { ProgressView().controlSize(.small)
                    Text("再想想…").font(.system(size: 12)).foregroundStyle(theme.textMuted) }
            } else {
                Button { more() } label: {
                    Label(rounds.isEmpty ? "再讲深一点" : "还想更多",
                          systemImage: "plus.bubble")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(theme.accentText)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(theme.accent.opacity(0.14), in: Capsule())
                }.buttonStyle(.plain)
            }

            if let failed {
                Text(failed).font(.system(size: 12)).lineSpacing(2)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onDisappear { speaker.stop() }
    }

    private func more() {
        guard !loading else { return }
        loading = true; failed = nil
        let sofar = ([alreadyShown()] + rounds).joined(separator: "\n\n")
        Task {
            let out = await WordStudy.deepen(topic: topic, sofar: sofar,
                                             context: context, language: language)
            await MainActor.run {
                loading = false
                if let out { rounds.append(out) }
                else {
                    failed = CloudLLM.isConfigured
                        ? "这次没讲出更多（云端连不上，本机也没写出来）。"
                        : "这次没讲出更多——需要本机的 Apple 智能，或在设置里填云端地址。"
                }
            }
        }
    }

    private func speak(_ text: String, id: String) {
        if speaker.speakingId == id { speaker.stop(); return }
        let segs = LessonSpeech.segments(for: text, foreignLanguage: language)
        guard !segs.isEmpty else { return }
        speaker.speakSequence(id: id, segments: segs)
    }

    private func rendered(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s,
                               options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(s)
    }
}
