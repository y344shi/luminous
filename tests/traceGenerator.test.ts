import { describe, it, expect } from "vitest";
import { generateTraceText, buildTrace, buildRestTrace } from "@/lib/traceGenerator";
import { materializeSeed, mockSeeds } from "@/lib/mockSeeds";
import { copy } from "@core/copy";

const seed = materializeSeed(mockSeeds[1]); // 坐一会野外 (recovery)

describe("traceGenerator", () => {
  it("completed trace starts with the warm prefix", () => {
    const text = generateTraceText(seed, "completed");
    expect(text.startsWith(copy.tracePrefix)).toBe(true);
  });

  it("partial completion still produces a positive trace", () => {
    const text = generateTraceText(seed, "partial");
    expect(text.startsWith(copy.tracePrefix)).toBe(true);
    expect(text).toMatch(/靠近|一点|也算|没有完全放弃/);
  });

  it("partial trace never shames", () => {
    const text = generateTraceText(seed, "partial");
    expect(text).not.toMatch(/失败|没用|浪费/);
  });

  it("skipped returns a gentle, non-disappear message", () => {
    const text = generateTraceText(seed, "skipped");
    expect(text).toBe(copy.completion.skippedMsg);
  });

  it("buildRestTrace records 'stopping' warmly, as recovery, not shaming", () => {
    const t = buildRestTrace(undefined, new Date("2026-06-25T23:30:00"));
    expect(t.text.startsWith(copy.tracePrefix)).toBe(true);
    expect(t.text).toContain("停下来");
    expect(t.text).not.toMatch(/失败|放弃|浪费/);
    expect(t.category).toBe("recovery");
    expect(t.partial).toBe(false);
    expect(t.date).toBe("2026-06-25");
  });

  it("buildTrace tags date and partial flag", () => {
    const t = buildTrace(seed, "partial", "opp_1", new Date("2026-06-25T20:00:00"));
    expect(t.date).toBe("2026-06-25");
    expect(t.partial).toBe(true);
    expect(t.category).toBe("recovery");
  });
});
