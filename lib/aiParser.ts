import { parseSeedMock, type SeedDraft } from "@core/seedParser";

export type AiMode = "mock" | "real";

/**
 * Single seam between the UI and "how a wish becomes a Seed draft".
 * - mock mode: pure local rule parser (default, offline, no network).
 * - real mode: ask the server route, which may use a real AI model if a
 *   server-side key is configured. ANY failure falls back to the local
 *   parser so the core loop (Add → Seed) can never break.
 *
 * Only the short wish text is ever sent — no GPS, no profile, no biometrics.
 */
export async function parseSeed(text: string, mode: AiMode = "mock"): Promise<SeedDraft> {
  if (mode !== "real") return parseSeedMock(text);
  try {
    const res = await fetch("/api/seeds/parse", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ text }),
    });
    if (!res.ok) throw new Error(`parse route ${res.status}`);
    const data = (await res.json()) as { draft?: SeedDraft };
    if (!data.draft || typeof data.draft.title !== "string") throw new Error("bad draft shape");
    return data.draft;
  } catch {
    // Fail soft: the app must always be able to catch a wish.
    return parseSeedMock(text);
  }
}
