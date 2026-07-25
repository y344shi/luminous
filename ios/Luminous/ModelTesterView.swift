//
//  ModelTesterView.swift
//  Luminous — a small dialogue tester for the models, in Settings.
//
//  Type to the on-device model (Apple Intelligence) or the cloud endpoint and see
//  exactly what comes back — including the system's own error text when it fails.
//  This is a diagnostic, not a feature of the app's voice: it's the fastest way to
//  tell "the model is off" from "the model is on but this request failed".
//

import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Holds a live on-device conversation, so turns build on each other. Untyped
/// storage keeps this compiling on OSes without FoundationModels.
@MainActor
final class LocalChatSession {
    private var session: AnyObject?

    func reset(instructions: String) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            session = LanguageModelSession(instructions: instructions)
            return
        }
        #endif
        session = nil
    }

    /// Returns the reply, or a message starting with "⚠️" describing the failure.
    func send(_ text: String, instructions: String) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else {
                return "⚠️ 本机模型不可用 · \(AIHelper.statusLine)"
            }
            if session == nil { reset(instructions: instructions) }
            guard let s = session as? LanguageModelSession else { return "⚠️ 没能创建会话" }
            do {
                let r = try await s.respond(to: text)
                let out = r.content.trimmingCharacters(in: .whitespacesAndNewlines)
                return out.isEmpty ? "⚠️ 模型返回了空内容" : out
            } catch {
                return "⚠️ 出错 · \(error.localizedDescription)"
            }
        }
        #endif
        return "⚠️ 这台设备没有本机模型（需要 iOS 26 + Apple 智能）"
    }
}

private struct ChatMsg: Identifiable, Equatable {
    let id = UUID()
    let mine: Bool
    let text: String
    var seconds: Double? = nil
}

struct ModelTesterView: View {
    @Environment(\.theme) private var theme

    private enum Backend: String, CaseIterable, Identifiable {
        case local = "本机"
        case cloud = "云端"
        var id: String { rawValue }
    }

    @State private var backend: Backend = .local
    @State private var messages: [ChatMsg] = []
    @State private var input = ""
    @State private var sending = false
    @State private var chat = LocalChatSession()

    var body: some View {
        VStack(spacing: 0) {
            statusBar
            transcript
            composer
        }
        .themedScreen()
        .navigationTitle("模型对话测试")
        .inlineNavTitle()
    }

    private var statusBar: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Picker("", selection: $backend) {
                ForEach(Backend.allCases) { b in Text(b.rawValue).tag(b) }
            }
            .pickerStyle(.segmented)
            .onChange(of: backend) { _, _ in messages.removeAll() }

            HStack(spacing: 6) {
                Circle().fill(ready ? theme.accent : theme.textMuted).frame(width: 7, height: 7)
                Text(statusText).font(.system(size: 12)).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if !messages.isEmpty {
                    Button("清空") { messages.removeAll(); chat = LocalChatSession() }
                        .font(.system(size: 12)).foregroundStyle(theme.accentText)
                }
            }
        }
        .padding(Spacing.md)
        .background(theme.surfaceSoft.opacity(0.6))
    }

    private var ready: Bool {
        backend == .local ? AIHelper.isAvailable : CloudLLM.isConfigured
    }

    private var statusText: String {
        if backend == .local { return "本机（Apple 智能）· \(AIHelper.statusLine)" }
        if CloudLLM.localOnly { return "云端已关闭（“只用本机 AI”开着）" }
        let base = CloudLLM.baseURL
        return base.isEmpty ? "还没填云端地址" : "云端 · \(base)"
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.sm) {
                    if messages.isEmpty { hint }
                    ForEach(messages) { m in bubble(m).id(m.id) }
                    if sending {
                        HStack(spacing: 8) { ProgressView().controlSize(.small)
                            Text("在想…").font(.system(size: 12)).foregroundStyle(theme.textMuted) }
                            .padding(.horizontal, Spacing.md)
                    }
                }
                .padding(.vertical, Spacing.md)
            }
            .onChange(of: messages) { _, _ in
                if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    private var hint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("随便说点什么，看模型答不答得上来。失败时会把系统自己的报错原样显示出来。")
                .font(.system(size: 13)).lineSpacing(3).foregroundStyle(theme.textSecondary)
            FlowLayout(spacing: Spacing.sm) {
                ForEach(["你好", "用一句话解释 le/la 的区别", "把 Le petit chat dort. 翻译成中文"], id: \.self) { s in
                    Button { input = s } label: {
                        Text(s).font(.system(size: 12)).foregroundStyle(theme.accentText)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(theme.accent.opacity(0.14), in: Capsule())
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    private func bubble(_ m: ChatMsg) -> some View {
        let failed = m.text.hasPrefix("⚠️")
        return VStack(alignment: m.mine ? .trailing : .leading, spacing: 2) {
            Text(m.text)
                .font(.system(size: 14)).lineSpacing(3)
                .textSelection(.enabled)
                .foregroundStyle(m.mine ? theme.accentText : theme.textPrimary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(m.mine ? theme.accent.opacity(0.16)
                                   : (failed ? Color.orange.opacity(0.12) : theme.surface))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(failed ? Color.orange.opacity(0.5) : theme.border, lineWidth: 0.5))
            if let s = m.seconds {
                Text(String(format: "%.1fs", s))
                    .font(.system(size: 10)).foregroundStyle(theme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: m.mine ? .trailing : .leading)
        .padding(.horizontal, Spacing.md)
    }

    private var composer: some View {
        HStack(spacing: Spacing.sm) {
            TextField("说点什么…", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 15))
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(theme.border, lineWidth: 1))
                .onSubmit { send() }
            Button { send() } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 28))
                    .foregroundStyle(canSend ? theme.accentText : theme.textMuted.opacity(0.5))
            }
            .buttonStyle(.plain).disabled(!canSend)
        }
        .padding(Spacing.md)
        .background(theme.surfaceSoft.opacity(0.6))
    }

    private var canSend: Bool {
        !sending && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !sending else { return }
        input = ""
        messages.append(ChatMsg(mine: true, text: text))
        sending = true
        let started = Date()
        let mode = backend
        Task {
            let reply: String
            if mode == .local {
                reply = await chat.send(text, instructions: AIHelper.testerInstructions)
            } else if !CloudLLM.isConfigured {
                reply = CloudLLM.localOnly
                    ? "⚠️ “只用本机 AI”开着，云端被跳过了。"
                    : "⚠️ 还没填云端地址。"
            } else {
                let out = await CloudLLM.chat(system: AIHelper.testerInstructions,
                                              user: text, maxTokens: 600, timeout: 120)
                reply = out ?? "⚠️ 云端没有返回（连不上、超时，或地址/密钥不对）。"
            }
            let dt = Date().timeIntervalSince(started)
            await MainActor.run {
                sending = false
                messages.append(ChatMsg(mine: false, text: reply, seconds: dt))
            }
        }
    }
}
