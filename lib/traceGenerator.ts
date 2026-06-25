import type { Seed, DailyTrace, SeedCategory } from "./types";
import { uid, nowIso, localDateKey } from "./utils";
import { copy } from "./copy";

export type CompletionKind = "completed" | "partial" | "skipped";

// Per-category warm completions. "今天没有消失，因为" + reason.
const completedReasons: Record<SeedCategory, string> = {
  body: "你照顾了一下自己的身体",
  creation: "你亲手做出了一点点东西",
  connection: "你和一个人之间多了一点真实的连接",
  exploration: "你让自己去了一个地方",
  recovery: "你给自己留了一点喘息",
  learning: "你让脑子里多了一点新的东西",
  aesthetic: "你停下来，看见了一点美",
};

const partialLines = [
  "你做了一点点，也算",
  "你没有完全放弃这个愿望",
  "你至少朝那个愿望靠近了一点",
];

/**
 * Generate the daily trace sentence for a completion event.
 * Partial completion always produces a kind, non-shaming line.
 */
export function generateTraceText(
  seed: Seed | undefined,
  kind: CompletionKind
): string {
  const prefix = copy.tracePrefix; // 今天没有消失，因为

  if (kind === "skipped") {
    // Skipped does not produce a "disappeared" line; caller may not save it.
    return copy.completion.skippedMsg;
  }

  if (kind === "partial") {
    // Deterministic-but-varied pick based on seed id length (no RNG in tests).
    const idx = seed ? seed.id.length % partialLines.length : 0;
    return `${prefix}${partialLines[idx]}。`;
  }

  // completed
  if (seed) {
    const cat = seed.categories[0];
    const reason = completedReasons[cat] ?? `你朝「${seed.title}」靠近了一点`;
    return `${prefix}${reason}。`;
  }
  return `${prefix}你留下了一个真实的瞬间。`;
}

/**
 * Choosing to stop is itself a real act (brief §17: "因为你及时停下来了").
 * The "今天先这样" path can optionally record this — never automatically.
 */
export function buildRestTrace(opportunityId?: string, date: Date = new Date()): DailyTrace {
  return {
    id: uid("trace"),
    date: localDateKey(date),
    opportunityId,
    text: `${copy.tracePrefix}你及时停下来了。`,
    category: "recovery",
    partial: false,
    createdAt: nowIso(),
  };
}

export function buildTrace(
  seed: Seed | undefined,
  kind: CompletionKind,
  opportunityId?: string,
  date: Date = new Date()
): DailyTrace {
  return {
    id: uid("trace"),
    date: localDateKey(date),
    seedId: seed?.id,
    opportunityId,
    text: generateTraceText(seed, kind),
    category: seed?.categories[0],
    partial: kind === "partial",
    createdAt: nowIso(),
  };
}
