//
// server.mjs — Luminous lesson proxy (personal, subscription-powered).
//
// A minimal HTTP server that answers `POST /generate {system, prompt}` by asking
// Claude through the Claude Agent SDK. The Agent SDK authenticates with your
// logged-in Claude account (the same profile Claude Code / `ant auth login` use),
// so this runs on your subscription — no API key, no per-token bill. Personal
// use only; keep it on your LAN.
//
// Run:  npm install  &&  node server.mjs
// Auth: log in once with Claude Code (`claude`) or `ant auth login`.
//

import http from "node:http";
import { query } from "@anthropic-ai/claude-agent-sdk";

const PORT = process.env.PORT ? Number(process.env.PORT) : 8787;
const TOKEN = process.env.PROXY_TOKEN || ""; // optional shared secret

/** Ask Claude for one text answer via the Agent SDK (uses your subscription). */
async function generate(systemPrompt, userPrompt) {
  let finalResult = "";
  let assistantText = "";
  for await (const message of query({
    prompt: userPrompt,
    options: {
      // A plain custom system prompt; no Claude Code preset, no tools — this is a
      // one-shot text generation, not a coding agent.
      systemPrompt: systemPrompt || undefined,
      allowedTools: [],
      maxTurns: 1,
      // model: "claude-opus-4-8", // optional; omit to use the account default
    },
  })) {
    if (message.type === "assistant") {
      for (const block of message.message?.content ?? []) {
        if (block.type === "text" && typeof block.text === "string") assistantText += block.text;
      }
    } else if (message.type === "result" && message.subtype === "success") {
      if (typeof message.result === "string") finalResult = message.result;
    }
  }
  return (finalResult || assistantText).trim();
}

function send(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, { "content-type": "application/json", "content-length": Buffer.byteLength(body) });
  res.end(body);
}

function readBody(req, limitBytes = 1_000_000) {
  return new Promise((resolve, reject) => {
    let data = "", size = 0;
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > limitBytes) { reject(new Error("body too large")); req.destroy(); return; }
      data += chunk;
    });
    req.on("end", () => resolve(data));
    req.on("error", reject);
  });
}

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === "GET" && req.url === "/health") {
      return send(res, 200, { ok: true, service: "luminous-lesson-proxy", auth: TOKEN ? "token" : "open" });
    }
    if (req.method === "POST" && req.url === "/generate") {
      if (TOKEN) {
        const auth = req.headers["authorization"] || "";
        if (auth !== `Bearer ${TOKEN}`) return send(res, 401, { error: "unauthorized" });
      }
      const raw = await readBody(req);
      let payload;
      try { payload = JSON.parse(raw || "{}"); }
      catch { return send(res, 400, { error: "invalid json" }); }
      const prompt = (payload.prompt || "").toString();
      if (!prompt.trim()) return send(res, 400, { error: "missing prompt" });
      const text = await generate((payload.system || "").toString(), prompt);
      return send(res, 200, { text });
    }
    return send(res, 404, { error: "not found" });
  } catch (err) {
    return send(res, 500, { error: String(err && err.message ? err.message : err) });
  }
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Luminous lesson proxy on http://0.0.0.0:${PORT}` + (TOKEN ? " (token required)" : " (open — set PROXY_TOKEN to lock it)"));
  console.log("Auth: uses your Claude subscription via the Claude Agent SDK (log in with `claude` or `ant auth login`).");
});
