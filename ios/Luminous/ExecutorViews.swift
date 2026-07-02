//
//  ExecutorViews.swift
//  Luminous — the AI as a pair of hands, one small help per kind of wish
//
//  Executors are OFFERS inside an opened wish card — never auto-run, never
//  pushed. Each follows the house LLM pattern: @Generable structured output,
//  graceful degradation when the model's away, ForbiddenWords on everything
//  shown. RecoveryBreath is deliberately model-free: rest needs no cleverness.
//
//  • ReviewQuiz     (learning)   — one learned word, three meanings, tap to check
//  • CreationSpark  (creation)   — a single opening line grown from today
//  • ConnectionDraft(connection) — one honest first sentence, copy-only
//  • RecoveryBreath (recovery/body) — a 3-breath script, plain and quiet
//

import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Structured outputs

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenQuiz {
    @Guide(description: "从已学过的词里选出的那个词，原样返回")
    var word: String
    @Guide(description: "这个词的正确中文意思（简短）")
    var correctMeaning: String
    @Guide(description: "一个貌似合理但错误的中文意思")
    var wrong1: String
    @Guide(description: "另一个貌似合理但错误的中文意思")
    var wrong2: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenLine {
    @Guide(description: "一句话，温柔、具体、不布置作业、不评判")
    var line: String
}
#endif

// MARK: - The section a wish card shows

/// All executors that apply to this seed, stacked. Empty when none do.
struct ExecutorSection: View {
    let seed: Seed
    @Environment(AppStore.self) private var store

    var body: some View {
        let cats = Set(seed.categories)
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let lang = LearningTopic.language(ofTitle: seed.title),
               !store.learnedWords(lang).isEmpty {
                ReviewQuizView(language: lang)
            }
            if cats.contains(.creation) {
                SparkLineView(
                    title: "给我一个开头",
                    loading: "在想一个开头…",
                    instructions: "你帮一个想写点什么的人起一个开头。只给一句话，具体、贴近此刻，不宏大、不布置作业。",
                    promptContext: { store in
                        let today = store.tracesForToday().map(\.text).joined(separator: "；")
                        return "今天的痕迹：\(today.isEmpty ? "还没有" : today)"
                    },
                    copyable: false)
            }
            if cats.contains(.connection) {
                SparkLineView(
                    title: "帮我起一句真话",
                    loading: "在想那句话…",
                    instructions: "你帮一个想联系某人的人起第一句话。真诚、简短、不客套、不讨好。只写那一句。绝不代替发送。",
                    promptContext: { _ in "想给一个忽然想起的人发第一句话。" },
                    copyable: true)
            }
            if cats.contains(.recovery) || cats.contains(.body) {
                BreathView()
            }
        }
    }
}

// MARK: - ReviewQuiz — spaced review of learned words

struct ReviewQuizView: View {
    let language: String
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme

    @State private var loading = false
    @State private var word: String?
    @State private var options: [String] = []
    @State private var correct: String?
    @State private var pickedOption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let word, !options.isEmpty {
                Text("还记得这个词吗？")
                    .font(.system(size: 12)).foregroundStyle(theme.textMuted)
                Text(word).font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                ForEach(options, id: \.self) { opt in
                    Button { pickedOption = opt } label: {
                        HStack {
                            Text(opt).font(.system(size: 14))
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            if let pickedOption {
                                if opt == correct {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green.opacity(0.8))
                                } else if opt == pickedOption {
                                    Image(systemName: "moon.zzz")
                                        .foregroundStyle(theme.textMuted)
                                }
                            }
                        }
                        .padding(Spacing.sm)
                        .background(theme.surfaceSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(pickedOption != nil)
                }
                if pickedOption != nil {
                    Text(pickedOption == correct ? "还在呢。" : "没关系，它会再来。")
                        .font(.system(size: 12)).foregroundStyle(theme.textSecondary)
                }
            } else if AIHelper.isAvailable {
                Button { run() } label: {
                    HStack(spacing: 6) {
                        if loading { ProgressView().controlSize(.small) }
                        else { Image(systemName: "arrow.uturn.left.circle") }
                        Text(loading ? "在挑一个学过的词…" : "复习一个学过的\(language)词")
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

    private func run() {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        loading = true
        // Oldest-learned first — the ones most worth touching again.
        let pool = Array(store.learnedWords(language).prefix(8))
        Task { @MainActor in
            defer { loading = false }
            let instructions = "你在帮人温习学过的外语词。选一个词，给出它正确的中文意思和两个貌似合理的错误意思。都要简短。"
            let prompt = "语言：\(language)。学过的词（越靠前学得越早）：\(pool.joined(separator: "、"))。"
            guard let r = try? await LanguageModelSession(instructions: instructions)
                .respond(to: prompt, generating: GenQuiz.self) else { return }
            let g = r.content
            guard ForbiddenWords.passes(g.correctMeaning + g.wrong1 + g.wrong2) else { return }
            word = g.word
            correct = g.correctMeaning
            // deterministic shuffle so the correct answer isn't always first
            options = [g.correctMeaning, g.wrong1, g.wrong2]
                .sorted { $0.hashValue < $1.hashValue }
            pickedOption = nil
            store.logLearning(LearningEntry(kind: .vocab, language: language,
                                            items: [g.word], note: "复习"))
        }
        #endif
    }
}

// MARK: - One-line spark (creation / connection)

struct SparkLineView: View {
    let title: String
    let loading: String
    let instructions: String
    let promptContext: (AppStore) -> String
    let copyable: Bool

    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var busy = false
    @State private var line: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let line {
                Text(line)
                    .font(.system(size: 15)).lineSpacing(4)
                    .foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.md)
                    .background(theme.surfaceSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .textSelection(.enabled)
                if copyable {
                    Button {
                        #if os(iOS)
                        UIPasteboard.general.string = line
                        #endif
                    } label: {
                        Label("抄走这句（发不发由你）", systemImage: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            } else if AIHelper.isAvailable {
                Button { run() } label: {
                    HStack(spacing: 6) {
                        if busy { ProgressView().controlSize(.small) }
                        else { Image(systemName: "sparkles") }
                        Text(busy ? loading : title)
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
                .disabled(busy)
            }
        }
    }

    private func run() {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        busy = true
        let ctx = promptContext(store)
        let inst = instructions
        Task { @MainActor in
            defer { busy = false }
            guard let r = try? await LanguageModelSession(instructions: inst)
                .respond(to: ctx, generating: GenLine.self) else { return }
            let text = r.content.line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty, ForbiddenWords.passes(text) { line = text }
        }
        #endif
    }
}

// MARK: - RecoveryBreath — no model, just three breaths

struct BreathView: View {
    @Environment(\.theme) private var theme
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button { withAnimation(.easeInOut(duration: 0.3)) { open.toggle() } } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wind")
                    Text("先呼吸三次").font(.system(size: 14, weight: .medium))
                    Spacer()
                    Image(systemName: open ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                }
                .foregroundStyle(theme.textPrimary)
                .padding(.vertical, 10).padding(.horizontal, Spacing.md)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            if open {
                VStack(alignment: .leading, spacing: 6) {
                    Text("一 · 吸气四秒，感觉空气进来")
                    Text("二 · 停两秒，什么都不用做")
                    Text("三 · 呼气六秒，肩膀放下来")
                    Text("就这样。够了。")
                }
                .font(.system(size: 14)).lineSpacing(4)
                .foregroundStyle(theme.textSecondary)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surfaceSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .transition(.opacity)
            }
        }
    }
}
