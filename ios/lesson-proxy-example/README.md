# Luminous lesson proxy (personal, subscription-powered)

A tiny HTTP server that powers Luminous's lessons/notes/word-cards with **your
own Claude subscription** — the same way **Claude Code** does. It uses the
**Claude Agent SDK** (`@anthropic-ai/claude-agent-sdk`), which authenticates
through your logged-in Claude account, so there is **no per-token API bill** and
no API key to paste into the app.

> This is a *personal* tool: it runs on your Mac and the app calls it over your
> local network. It is not for distributing to other people (that's what an API
> key or a hosted backend is for), and it only works while the Mac is on and
> reachable. Use it within Anthropic's terms for your subscription.

```
 iPhone / iPad (Luminous)  ──HTTP──►  this proxy on your Mac  ──►  Claude (your subscription)
        LAN / Wi-Fi                    node server.mjs                via Claude Agent SDK
```

## 1. Prerequisites (once)

- **Node 18+** (`node -v`).
- **Log in with your Claude subscription.** Either is fine:
  - Claude Code: `npm i -g @anthropic-ai/claude-code` then run `claude` once and sign in, **or**
  - the Anthropic CLI: `npm i -g @anthropic-ai/cli` then `ant auth login`.
  The Agent SDK picks up whichever profile is active — the same resolution Claude
  Code uses. (If `ANTHROPIC_API_KEY` is set in your shell it will win over the
  subscription profile — `unset ANTHROPIC_API_KEY` to use the subscription.)
- Install this folder's dep:
  ```bash
  cd ios/lesson-proxy-example
  npm install
  ```

## 2. Run it

```bash
# optional: require a shared token so only your app can call it
export PROXY_TOKEN="pick-a-long-random-string"
node server.mjs
# → Luminous lesson proxy on http://0.0.0.0:8787
```

Leave it running (or wrap it in `pm2` / a `launchd` plist to keep it up).

## 3. Test it

```bash
curl -s http://localhost:8787/health
# {"ok":true,...}

curl -s http://localhost:8787/generate \
  -H "content-type: application/json" \
  -H "authorization: Bearer $PROXY_TOKEN" \
  -d '{
        "system": "你是一位耐心的法语老师。只输出内容本身，不要寒暄。",
        "prompt": "逐词讲解这句法语，每个词给出英文和中文意思：«Bonjour le monde»"
      }'
# {"text":"..."}
```

## 4. Point Luminous at it

The app already routes lessons/notes/word-cards through the on-device model with a
fallback. To add a "use my Mac" option, add a provider that POSTs to `/generate`
with the same instructions the templates already build, and prefer it when a proxy
URL is set in Settings. Sketch of the Swift side:

```swift
struct CloudLessonProvider {
    let baseURL: URL        // e.g. http://192.168.1.20:8787  (your Mac's LAN IP)
    let token: String?      // matches PROXY_TOKEN, if set

    func generate(system: String, prompt: String) async -> String? {
        var req = URLRequest(url: baseURL.appendingPathComponent("generate"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "authorization") }
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["system": system, "prompt": prompt])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj["text"] as? String
    }
}
```

Then in `WordStudyAI` / `PromptTemplates`, if a proxy is configured, call
`CloudLessonProvider.generate(system: PromptTemplates.instructions(.lesson),
prompt: …)` first and fall back to the on-device model. (Local network access
prompts the user for permission on iOS 14+, which is expected.)

## Notes & caveats

- **Mac must be up and reachable.** Great at home; not for reading on the metro.
  For anywhere-access, use a bring-your-own **API key** instead (separate billing).
- **LAN only by default.** Don't expose port 8787 to the public internet. If you
  must reach it away from home, tunnel it (Tailscale, `cloudflared`) rather than
  port-forwarding, and keep `PROXY_TOKEN` set.
- **The book text leaves the device** when a page is sent to the proxy → Claude —
  the same privacy trade-off as any cloud model. Keep it opt-in.
- Agent SDK docs: https://code.claude.com/docs/en/agent-sdk
