import { describe, it, expect } from "vitest";
import { dwellLevel, advanceDwell } from "@core/dwell";
import { dwellBonus } from "@core/scoring";
import type { Seed, ContextSnapshot } from "@core/types";

describe("dwell model", () => {
  it("dwellLevel buckets minutes", () => {
    expect(dwellLevel(10)).toBe("fresh");
    expect(dwellLevel(60)).toBe("settled");
    expect(dwellLevel(180)).toBe("long");
  });
  it("advanceDwell accumulates active desk time, ignores gaps + off-desk, resets on a new day", () => {
    let r = advanceDwell(null, "2026-06-28", 60_000, true);
    expect(r.deskMs).toBe(60_000);
    r = advanceDwell(r, "2026-06-28", 60_000, true);
    expect(r.deskMs).toBe(120_000);
    r = advanceDwell(r, "2026-06-28", 60_000, false); // away from desk
    expect(r.deskMs).toBe(120_000);
    r = advanceDwell(r, "2026-06-28", 9_999_999, true); // huge gap (tab slept)
    expect(r.deskMs).toBe(120_000);
    r = advanceDwell(r, "2026-06-29", 60_000, true); // new day resets
    expect(r.deskMs).toBe(60_000);
  });
});

const seed = (over: Partial<Seed>): Seed => ({
  id: "s", rawText: "", title: "t", categories: ["creation"], minimumAction: "",
  estimatedDurationMin: 30, energyRequired: "medium", locationType: "computer",
  preferredTimes: [], triggerConditions: [], status: "active",
  createdAt: "", updatedAt: "", ...over,
});
const ctx = (deskMinutesToday?: number): ContextSnapshot => ({
  timestamp: "", semanticTime: "afternoon", mood: "unknown", energy: "medium",
  isLateNight: false, locationHint: "computer", deskMinutesToday,
});

describe("dwellBonus", () => {
  it("does nothing when dwell is unknown or fresh", () => {
    expect(dwellBonus(seed({}), ctx(undefined))).toBe(0);
    expect(dwellBonus(seed({ categories: ["body"] }), ctx(20))).toBe(0);
  });
  it("after a long sit, favors body/recovery and eases off computer focus", () => {
    expect(dwellBonus(seed({ categories: ["recovery"] }), ctx(180))).toBeGreaterThan(0);
    expect(dwellBonus(seed({ categories: ["body"], locationType: "outdoor" }), ctx(180))).toBeGreaterThan(0);
    expect(dwellBonus(seed({ categories: ["creation"], locationType: "computer" }), ctx(180))).toBeLessThan(0);
  });
  it("stays capped", () => {
    const b = dwellBonus(seed({ categories: ["body", "recovery"], locationType: "outdoor" }), ctx(300));
    expect(Math.abs(b)).toBeLessThanOrEqual(0.2);
  });
});
