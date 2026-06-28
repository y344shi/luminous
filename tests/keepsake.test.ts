import { describe, it, expect } from "vitest";
import { wrapByWidth, keepsakeFilename } from "@/lib/keepsake";

describe("keepsake", () => {
  it("wraps long text into lines within the max width", () => {
    const lines = wrapByWidth("今天没有消失，因为我记了三个法语单词，做了一点点", 8);
    expect(lines.length).toBeGreaterThan(1);
    for (const l of lines) expect(l.length).toBeLessThanOrEqual(8);
  });

  it("preserves explicit newlines", () => {
    const lines = wrapByWidth("第一行\n第二行", 20);
    expect(lines).toEqual(["第一行", "第二行"]);
  });

  it("short text stays on one line", () => {
    expect(wrapByWidth("很短", 13)).toEqual(["很短"]);
  });

  it("filename uses a valid date, else a safe fallback", () => {
    expect(keepsakeFilename("2026-06-26")).toBe("今天别消失-2026-06-26.png");
    expect(keepsakeFilename("garbage")).toBe("今天别消失-trace.png");
    expect(keepsakeFilename()).toBe("今天别消失-trace.png");
  });
});
