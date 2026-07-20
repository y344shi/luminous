//
//  CloudLLM.swift
//  Luminous — optional cloud model behind a base URL you enter.
//
//  Point this at any OpenAI-compatible server (your own H200 running vLLM /
//  SGLang / TGI / Ollama, or any hosted endpoint): Settings → 高级 · 云端讲解
//  takes a Base URL, an API key, and a model name. When configured, the study
//  generators (小课 / 读书笔记 / 点词讲解 / 译文) call it FIRST and fall back to
//  the on-device model when it's unreachable. Everything shown still passes
//  ForbiddenWords. Uses /v1/chat/completions with a {system,user} pair.
//
//  Privacy: with this on, the page text leaves the device for your endpoint —
//  a deliberate, off-by-default choice. iOS requires HTTPS (App Transport
//  Security), so the Base URL should be https://…
//

import Foundation

enum CloudLLM {
    private enum Key {
        static let base = "tdd.cloud.baseURL"
        static let apiKey = "tdd.cloud.apiKey"
        static let model = "tdd.cloud.model"
    }

    // MARK: config (persisted)

    static var baseURL: String {
        get { UserDefaults.standard.string(forKey: Key.base) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespaces), forKey: Key.base) }
    }
    static var apiKey: String {
        get { UserDefaults.standard.string(forKey: Key.apiKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespaces), forKey: Key.apiKey) }
    }
    static var model: String {
        get { UserDefaults.standard.string(forKey: Key.model) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespaces), forKey: Key.model) }
    }

    /// Configured = a base URL is set. (Key/model are recommended but optional.)
    static var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: endpoint

    private static func chatURL() -> URL? {
        var s = baseURL.trimmingCharacters(in: .whitespaces)
        while s.hasSuffix("/") { s.removeLast() }
        guard !s.isEmpty else { return nil }
        if s.hasSuffix("/chat/completions") { return URL(string: s) }
        if s.hasSuffix("/v1") { return URL(string: s + "/chat/completions") }
        return URL(string: s + "/v1/chat/completions")
    }

    // MARK: one text turn

    static func chat(system: String, user: String, maxTokens: Int = 1200) async -> String? {
        guard let url = chatURL() else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let key = apiKey
        if !key.isEmpty { req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }

        var messages: [[String: Any]] = []
        if !system.isEmpty { messages.append(["role": "system", "content": system]) }
        messages.append(["role": "user", "content": user])
        var body: [String: Any] = [
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": maxTokens,
            "stream": false,
        ]
        let m = model
        if !m.isEmpty { body["model"] = m }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let msg = choices.first?["message"] as? [String: Any],
              let content = msg["content"] as? String
        else { return nil }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Ask for a JSON object and decode it — the cloud equivalent of the
    /// on-device @Generable structured output.
    static func json<T: Decodable>(system: String, user: String, as type: T.Type,
                                   maxTokens: Int = 1400) async -> T? {
        let sys = system + "\n\n只输出一个 JSON 对象，不要任何解释、前后缀或代码块标记。"
        guard let text = await chat(system: sys, user: user, maxTokens: maxTokens),
              let data = extractJSON(text) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// Pull the first {...} object out of a reply (tolerates ```json fences).
    private static func extractJSON(_ text: String) -> Data? {
        var s = text
        if let r = s.range(of: "```") {
            // drop everything up to the first fence, then the language tag line
            s = String(s[r.upperBound...])
            if let nl = s.firstIndex(of: "\n") { s = String(s[s.index(after: nl)...]) }
            if let end = s.range(of: "```") { s = String(s[..<end.lowerBound]) }
        }
        guard let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}"), start < end
        else { return nil }
        return String(s[start...end]).data(using: .utf8)
    }

    /// A quick liveness check for the Settings "测试连接" button.
    static func test() async -> Bool {
        (await chat(system: "You are a connectivity test.",
                    user: "Reply with the single word: OK", maxTokens: 8)) != nil
    }
}
