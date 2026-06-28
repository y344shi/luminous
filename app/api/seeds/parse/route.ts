import { NextResponse } from "next/server";
import { parseSeedMock, type SeedDraft } from "@core/seedParser";
import { SEED_PARSER_SYSTEM_PROMPT, parseModelDraft } from "@core/seedAiPrompt";

export const runtime = "nodejs";

const MODEL = "claude-haiku-4-5-20251001";

/**
 * Call Claude with ONLY the wish text. Returns a validated SeedDraft, or null
 * on any failure (network/parse/shape) so the caller falls back to the mock.
 * Uses global fetch — no SDK dependency, no key in the client, never hardcoded.
 */
async function callModel(text: string, apiKey: string): Promise<SeedDraft | null> {
  try {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 400,
        system: SEED_PARSER_SYSTEM_PROMPT,
        messages: [{ role: "user", content: text }],
      }),
    });
    if (!res.ok) return null;
    const data = (await res.json()) as { content?: Array<{ text?: string }> };
    const out = data.content?.map((c) => c.text ?? "").join("") ?? "";
    return parseModelDraft(out, text);
  } catch {
    return null;
  }
}

/**
 * POST /api/seeds/parse  { text: string }  →  { draft, source }
 *
 * Privacy: only the short wish text reaches this route — never location,
 * health, or identity. No API key is ever read from the client or hardcoded.
 *
 * Until a server-side model is configured (e.g. process.env.ANTHROPIC_API_KEY),
 * this returns the local rule-parser result, so the feature works everywhere.
 * The real-model branch is intentionally a documented seam, not a live call,
 * because it can't be exercised/tested without a key in this environment.
 */
export async function POST(req: Request) {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "invalid json" }, { status: 400 });
  }

  const text = (body as { text?: unknown })?.text;
  if (typeof text !== "string" || !text.trim()) {
    return NextResponse.json({ error: "empty text" }, { status: 400 });
  }
  if (text.length > 500) {
    return NextResponse.json({ error: "text too long" }, { status: 413 });
  }

  // With a server-side key, ask the model (coarse text only) and validate its
  // response; ANY failure falls back to the deterministic local parser so the
  // feature works everywhere and can never break the Add loop.
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (apiKey) {
    const aiDraft = await callModel(text, apiKey);
    if (aiDraft) return NextResponse.json({ draft: aiDraft, source: "ai" });
  }

  return NextResponse.json({ draft: parseSeedMock(text), source: "mock" });
}
