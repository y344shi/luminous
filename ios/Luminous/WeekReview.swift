//
//  WeekReview.swift
//  Luminous — one warm paragraph that proves the weeks aren't disappearing
//
//  On demand (a soft button atop 痕迹), the on-device model reads the last
//  seven days of traces + learning moments and hands back a single gentle
//  paragraph — noticing, never grading. No numbers, no completion talk;
//  ForbiddenWords guards the output, silence is the fallback.
//

import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenWeekReview {
    @Guide(description: "两三句话，温柔地回看这一周留下的痕迹。像朋友的注视，不是总结报告。没有数字、没有评分、不布置下周。")
    var paragraph: String
}
#endif

/// The card atop 痕迹: 回看这一周 → one paragraph, kept until the tab closes.
struct WeekReviewCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var loading = false
    @State private var text: String?

    var body: some View {
        if AIHelper.isAvailable, !store.traces.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let text {
                    Text(text)
                        .font(.system(size: 15)).lineSpacing(5)
                        .foregroundStyle(theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.md)
                        .background(theme.surfaceSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    Button { run() } label: {
                        HStack(spacing: 6) {
                            if loading { ProgressView().controlSize(.small) }
                            else { Image(systemName: "moon.stars") }
                            Text(loading ? "在轻轻回看…" : "回看这一周")
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
                    .disabled(loading)
                }
            }
        }
    }

    private func run() {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        loading = true
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let weekKey = DomainUtil.localDateKey(weekAgo)
        let traces = store.traces.filter { $0.date >= weekKey }.prefix(20)
            .map { "\($0.date)：\($0.text)" }.joined(separator: "\n")
        let learning = store.learningHistory.filter { $0.dateKey >= weekKey }.prefix(8)
            .map { "\($0.language)：\($0.items.joined(separator: "、"))" }
            .joined(separator: "\n")
        Task { @MainActor in
            defer { loading = false }
            let instructions = """
            你替一个温柔的生活锚点应用回看一周。只看给出的痕迹，像朋友一样注意到\
            其中的光。两三句话。不评分、不比较、不建议、不催。
            """
            let prompt = """
            这一周留下的痕迹：
            \(traces.isEmpty ? "（很安静的一周）" : traces)
            \(learning.isEmpty ? "" : "学过的东西：\n" + learning)
            """
            guard let r = try? await LanguageModelSession(instructions: instructions)
                .respond(to: prompt, generating: GenWeekReview.self) else { return }
            let t = r.content.paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty, ForbiddenWords.passes(t) { text = t }
        }
        #endif
    }
}
