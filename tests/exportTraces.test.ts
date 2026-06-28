import { describe, it, expect } from "vitest";
import { formatTracesForExport } from "@/lib/exportTraces";
import type { DailyTrace } from "@core/types";
import { copy } from "@core/copy";

const today = new Date(2026, 5, 25);

function trace(date: string, text: string, id = date + text): DailyTrace {
  return { id, date, text, createdAt: "" };
}

describe("formatTracesForExport", () => {
  it("returns empty string when there are no traces", () => {
    expect(formatTracesForExport([], today)).toBe("");
  });

  it("includes a title header and the trace text", () => {
    const out = formatTracesForExport([trace("2026-06-25", "今天没有消失，因为你喝了水")], today);
    expect(out).toContain(`${copy.appTitle} · 我的痕迹`);
    expect(out).toContain("今天没有消失，因为你喝了水");
  });

  it("groups by date newest-first with human headers", () => {
    const out = formatTracesForExport(
      [
        trace("2026-06-24", "昨天的事"),
        trace("2026-06-25", "今天的事"),
        trace("2026-06-25", "今天的另一件事"),
      ],
      today
    );
    const idxToday = out.indexOf("今天");
    const idxYesterday = out.indexOf("昨天");
    expect(idxToday).toBeGreaterThan(-1);
    expect(idxYesterday).toBeGreaterThan(idxToday); // 今天 block comes before 昨天
    // both same-day traces present as bullets
    expect(out).toContain("· 今天的事");
    expect(out).toContain("· 今天的另一件事");
  });

  it("uses bullet markers and trailing newline", () => {
    const out = formatTracesForExport([trace("2026-06-25", "x")], today);
    expect(out).toMatch(/· x/);
    expect(out.endsWith("\n")).toBe(true);
  });
});
