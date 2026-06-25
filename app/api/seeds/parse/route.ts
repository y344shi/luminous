import { NextResponse } from "next/server";
import { parseSeedMock } from "@/lib/seedParser";

export const runtime = "nodejs";

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

  const hasKey = Boolean(process.env.ANTHROPIC_API_KEY);
  // When a key is configured, a future implementation would call the model
  // here with ONLY `text` and validate the response against the SeedDraft
  // schema, falling back to the mock on any error. For now we always use the
  // deterministic local parser.
  const draft = parseSeedMock(text);

  return NextResponse.json({ draft, source: hasKey ? "ai-pending" : "mock" });
}
