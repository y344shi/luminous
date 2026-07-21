//
//  PromptTemplates.swift
//  Luminous — the teaching-style prompts behind the lessons, shown and editable.
//
//  Each AI study feature (word card / reading notes / 小课 lesson) is driven by an
//  "instructions" prompt — the teaching STYLE. We ship a system default for each
//  and let the user read it and, if they like, rewrite it (persisted). Whatever
//  the prompt says, the OUTPUT still passes ForbiddenWords, so the app's tone
//  safety holds regardless of what a custom prompt asks for.
//

import SwiftUI

enum PromptKind: String, CaseIterable, Identifiable {
    case word, notes, lesson
    var id: String { rawValue }

    var title: String {
        switch self {
        case .word:   return "点词讲解"
        case .notes:  return "读书笔记"
        case .lesson: return "小课"
        }
    }

    var blurb: String {
        switch self {
        case .word:   return "点一个词时，怎样讲它的意思、语法、用法和例句。"
        case .notes:  return "整页的读书笔记用什么风格、教什么。"
        case .lesson: return "小课怎样一步步带着逐词讲解这门语言。"
        }
    }

    /// A short sample the "试一下" preview runs on by default (a French line).
    var sampleText: String {
        switch self {
        case .word:   return "Le petit chat dort sous la table."
        case .notes:  return "Le petit chat dort sous la table. Il fait un rêve doux."
        case .lesson: return "Le petit chat dort sous la table."
        }
    }

    /// The system default instructions (the teaching style we ship with).
    var defaultInstructions: String {
        switch self {
        case .word:
            return """
            你在帮一个人读一本外语书。原文可能是任何语言，先认出这个词是什么语言。\
            给出这个词最基本的意思，简洁、准确：英文和简体中文各一个基本释义，\
            再加词性/语法、用法、一个带中文意思的例句。只解释这个词本身，\
            不要评论，不要鼓励或催促的话。
            """
        case .notes:
            return """
            你在帮一个人读一本外语书，目的是帮他学会这门外语。给这一页挑几条学习笔记，\
            每条聚焦原文里一个最有用的词、搭配或语法点：先写出原文里的那个词/短语，\
            再用英文和简体中文各解释一句它的意思和用法。既让他快速读懂，也真的学到这门语言。\
            不要评论，不要鼓励或催促的话。
            """
        case .lesson:
            return """
            你是一位耐心的语言老师，正带着学生逐词读这一页外语书。按原文顺序挑出主要的词和短语，\
            为每一个做一小步讲解：写出这个词/短语（保持原文语言），给出一句英文意思和一句简体中文意思，\
            再用两三句话讲清楚——它在这句话里的语法作用，以及它怎样和前后的词连起来（比如性数配合、\
            和哪个词搭配、指向谁、时态和语气）。像一堂真正在讲解、在把词与词连起来的小课，\
            不只是逐词翻译。不要评论，不要鼓励或催促的话。
            """
        }
    }
}

enum PromptTemplates {
    private static func key(_ k: PromptKind) -> String { "tdd.prompt.\(k.rawValue)" }

    /// The instructions actually used — the user's override, else the default.
    static func instructions(_ k: PromptKind) -> String {
        let saved = UserDefaults.standard.string(forKey: key(k))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let saved, !saved.isEmpty { return saved }
        return k.defaultInstructions
    }

    static func isCustom(_ k: PromptKind) -> Bool {
        let saved = UserDefaults.standard.string(forKey: key(k))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !saved.isEmpty && saved != k.defaultInstructions
    }

    /// Save an override (or clear it when equal to the default / empty).
    static func set(_ k: PromptKind, _ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t == k.defaultInstructions {
            UserDefaults.standard.removeObject(forKey: key(k))
        } else {
            UserDefaults.standard.set(t, forKey: key(k))
        }
    }

    static func reset(_ k: PromptKind) { UserDefaults.standard.removeObject(forKey: key(k)) }
}

// MARK: - editor

struct PromptEditorView: View {
    let kind: PromptKind
    @Environment(\.theme) private var theme
    @State private var text = ""
    @State private var sample = ""
    @State private var testing = false
    @State private var result: String?
    @State private var testedEmpty = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(kind.blurb)
                    .font(.system(size: 13)).lineSpacing(3).foregroundStyle(theme.textSecondary)

                Text("讲解风格（提示词）")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(theme.textMuted)
                TextEditor(text: $text)
                    .font(.system(size: 15)).lineSpacing(3)
                    .frame(minHeight: 180)
                    .padding(8)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1))

                Button { text = kind.defaultInstructions } label: {
                    Label("恢复系统默认", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(theme.accentText)
                }.buttonStyle(.plain)

                Divider().padding(.vertical, 4)

                testSection

                Divider().padding(.vertical, 4)

                Text("系统默认")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(theme.textMuted)
                Text(kind.defaultInstructions)
                    .font(.system(size: 13)).lineSpacing(3).foregroundStyle(theme.textSecondary)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surfaceSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("不管提示词怎么写，显示给你的内容都会经过用词过滤，保持温和。")
                    .font(.system(size: 12)).foregroundStyle(theme.textMuted)
            }
            .padding(Spacing.lg)
        }
        .themedScreen()
        .navigationTitle(kind.title)
        .inlineNavTitle()
        .onAppear {
            text = PromptTemplates.instructions(kind)
            if sample.isEmpty { sample = kind.sampleText }
        }
        .onDisappear { PromptTemplates.set(kind, text) }   // save on leave
    }

    // MARK: 试一下 — run the CURRENT prompt on a sample, live, ignoring the cache

    @ViewBuilder private var testSection: some View {
        Text("试一下")
            .font(.system(size: 12, weight: .medium)).foregroundStyle(theme.textMuted)
        Text("用上面这段提示词，现在就在一小句上跑一次，看看效果。不写进书里，也不受缓存影响。")
            .font(.system(size: 12)).lineSpacing(3).foregroundStyle(theme.textMuted)

        TextEditor(text: $sample)
            .font(.system(size: 14)).lineSpacing(3)
            .frame(minHeight: 60)
            .padding(8)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.border, lineWidth: 1))

        HStack(spacing: Spacing.sm) {
            Button {
                runTest()
            } label: {
                Label(testing ? "生成中…" : "试一下", systemImage: "play.circle.fill")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(theme.accentText)
            }
            .buttonStyle(.plain)
            .disabled(testing || sample.trimmingCharacters(in: .whitespaces).isEmpty)

            if !WordStudy.isAvailable {
                Text("需要 Apple Intelligence 或云端地址")
                    .font(.system(size: 12)).foregroundStyle(theme.textMuted)
            }
            Spacer()
        }

        if testing {
            HStack(spacing: 10) { ProgressView(); Text("正在用你的提示词生成…")
                .font(.system(size: 13)).foregroundStyle(theme.textSecondary) }
        } else if let result {
            Text(result)
                .font(.system(size: 14)).lineSpacing(4)
                .textSelection(.enabled)
                .foregroundStyle(theme.textPrimary)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surfaceSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if testedEmpty {
            Text("这次没有生成内容。可能是模型暂时不可用，或原文太短——换句样例再试。")
                .font(.system(size: 13)).lineSpacing(3).foregroundStyle(theme.textSecondary)
        }
    }

    private func runTest() {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = sample
        testing = true; result = nil; testedEmpty = false
        Task {
            let r = await WordStudy.preview(kind: kind,
                                            instructions: prompt.isEmpty ? kind.defaultInstructions : prompt,
                                            sample: s)
            await MainActor.run {
                testing = false
                result = r
                testedEmpty = (r == nil)
            }
        }
    }
}
