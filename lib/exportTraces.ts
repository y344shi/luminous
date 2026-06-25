import type { DailyTrace } from "./types";
import { friendlyDate } from "./utils";
import { copy } from "./copy";

/**
 * Render the trace journal as a plain-text keepsake — the user's "year rings",
 * theirs to keep. Pure + deterministic (today injectable). Grouped by date,
 * newest first, with human date headers. Returns "" when there's nothing yet.
 */
export function formatTracesForExport(
  traces: DailyTrace[],
  today: Date = new Date()
): string {
  if (traces.length === 0) return "";

  const byDate = new Map<string, DailyTrace[]>();
  for (const t of traces) {
    const arr = byDate.get(t.date) ?? [];
    arr.push(t);
    byDate.set(t.date, arr);
  }
  const dates = Array.from(byDate.keys()).sort((a, b) => (a < b ? 1 : -1));

  const blocks = dates.map((date) => {
    const lines = byDate
      .get(date)!
      .map((t) => `· ${t.text}`)
      .join("\n");
    return `${friendlyDate(date, today)}\n${lines}`;
  });

  return `${copy.appTitle} · 我的痕迹\n\n${blocks.join("\n\n")}\n`;
}
