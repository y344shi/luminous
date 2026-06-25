import { describe, it, expect } from "vitest";
import { rankSeeds, recommend, isUnsafeLateNight } from "@/lib/scoring";
import { ctx, garden, fixedRng } from "./helpers";

describe("scoring — late night safety", () => {
  it("never recommends downtown exploration late at night", () => {
    const seeds = garden();
    const ranked = rankSeeds(seeds, ctx({ isLateNight: true, semanticTime: "late_night", energy: "low", mood: "tired" }), { rng: fixedRng, limit: 8 });
    const titles = ranked.map((r) => r.seed.title);
    expect(titles).not.toContain("去市中心走走");
    expect(titles).not.toContain("亲手理解一个模块");
  });

  it("recommends rescue / stop-loss action late at night", () => {
    const seeds = garden();
    const ranked = rankSeeds(seeds, ctx({ isLateNight: true, semanticTime: "late_night", energy: "low", mood: "tired" }), { rng: fixedRng, limit: 3 });
    const titles = ranked.map((r) => r.seed.title);
    expect(titles).toContain("深夜止损");
    // rescue seed should rank first
    expect(ranked[0].seed.title).toBe("深夜止损");
  });

  it("flags unsafe seeds via isUnsafeLateNight", () => {
    const seeds = garden();
    const downtown = seeds.find((s) => s.title === "去市中心走走")!;
    const rescue = seeds.find((s) => s.title === "深夜止损")!;
    expect(isUnsafeLateNight(downtown)).toBe(true);
    expect(isUnsafeLateNight(rescue)).toBe(false);
  });
});

describe("scoring — mood shaping", () => {
  it("tired mood prefers body/recovery", () => {
    const seeds = garden();
    const ranked = rankSeeds(seeds, ctx({ mood: "tired", energy: "low" }), { rng: fixedRng, limit: 3 });
    const cats = ranked.flatMap((r) => r.seed.categories);
    expect(cats.some((c) => c === "body" || c === "recovery")).toBe(true);
    // top pick should be low energy
    expect(ranked[0].seed.energyRequired).toBe("low");
  });

  it("empty mood prefers recovery/connection/body/aesthetic", () => {
    const seeds = garden();
    const ranked = rankSeeds(seeds, ctx({ mood: "empty", energy: "low" }), { rng: fixedRng, limit: 3 });
    const cats = ranked.flatMap((r) => r.seed.categories);
    expect(cats.some((c) => ["recovery", "connection", "body", "aesthetic"].includes(c))).toBe(true);
  });

  it("anxious mood avoids high-energy actions at top", () => {
    const seeds = garden();
    const ranked = rankSeeds(seeds, ctx({ mood: "anxious", energy: "low" }), { rng: fixedRng, limit: 3 });
    expect(ranked[0].seed.energyRequired).not.toBe("high");
  });

  it("avoidant mood surfaces tiny creation, not a huge project", () => {
    const seeds = garden();
    const ranked = rankSeeds(seeds, ctx({ mood: "avoidant", energy: "medium", semanticTime: "evening" }), { rng: fixedRng, limit: 3 });
    const top = ranked[0].seed;
    expect(top.categories).toContain("creation");
    expect(top.estimatedDurationMin).toBeLessThanOrEqual(30);
  });

  it("want_love / lonely surfaces connection", () => {
    const seeds = garden();
    const ranked = rankSeeds(seeds, ctx({ mood: "lonely", energy: "low", semanticTime: "evening" }), { rng: fixedRng, limit: 3 });
    const cats = ranked.flatMap((r) => r.seed.categories);
    expect(cats).toContain("connection");
  });
});

describe("scoring — duration fit", () => {
  it("short free time prefers short actions", () => {
    const seeds = garden();
    const ranked = rankSeeds(seeds, ctx({ freeMinutes: 5, mood: "okay", energy: "low" }), { rng: fixedRng, limit: 3 });
    expect(ranked[0].seed.estimatedDurationMin).toBeLessThanOrEqual(15);
  });
});

describe("scoring — serendipity", () => {
  it("does not always return the same top seed under varied rng", () => {
    const seeds = garden();
    const tops = new Set<string>();
    for (let i = 0; i < 30; i++) {
      const r = Math.random;
      const ranked = rankSeeds(seeds, ctx({ mood: "okay", energy: "high", semanticTime: "weekend", isWeekend: true }), { rng: r, limit: 1 });
      tops.add(ranked[0].seed.id);
    }
    // With serendipity weight, multiple seeds can surface across runs.
    expect(tops.size).toBeGreaterThan(1);
  });

  it("recommend returns Opportunity objects with reasons", () => {
    const seeds = garden();
    const opps = recommend(seeds, ctx({ mood: "okay", energy: "medium" }), { rng: fixedRng });
    expect(opps.length).toBeGreaterThan(0);
    expect(opps[0].reason.length).toBeGreaterThan(0);
    expect(opps[0].notificationText).toContain("·");
  });
});
