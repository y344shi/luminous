import { describe, it, expect } from "vitest";
import { recommend } from "@core/scoring";
import { ctx, fixedRng } from "./helpers";
import type { Seed } from "@core/types";

const seed = (over: Partial<Seed>): Seed => ({
  id: "x", rawText: "", title: "x", categories: ["creation"], minimumAction: "做一点",
  estimatedDurationMin: 30, energyRequired: "medium", locationType: "computer",
  preferredTimes: [], triggerConditions: [], status: "active",
  createdAt: "", updatedAt: "", ...over,
});

/**
 * The sensor bonuses are unit-tested in isolation; this checks they actually
 * compose through scoreSeed → rankSeeds → recommend and move the real ranking.
 */
describe("sensor fusion — end to end through recommend", () => {
  const focus = seed({
    id: "focus", title: "focus",
    categories: ["creation", "learning"], locationType: "computer", estimatedDurationMin: 40,
  });
  const rest = seed({
    id: "rest", title: "rest",
    categories: ["recovery", "body"], locationType: "anywhere", estimatedDurationMin: 5, energyRequired: "low",
  });
  const seeds = [focus, rest];
  const score = (opps: { seedId: string; score: number }[], id: string) =>
    opps.find((o) => o.seedId === id)!.score;

  it("a weary context (long desk sit + low battery) lifts the restful wish and lowers the focus one", () => {
    const neutral = recommend(seeds, ctx({ locationHint: "computer" }), { rng: fixedRng, limit: 2 });
    const weary = recommend(
      seeds,
      ctx({ locationHint: "computer", deskMinutesToday: 220, batteryLow: true }),
      { rng: fixedRng, limit: 2 }
    );
    // the fused senses move the scores in the expected directions...
    expect(score(weary, "rest")).toBeGreaterThan(score(neutral, "rest"));
    expect(score(weary, "focus")).toBeLessThan(score(neutral, "focus"));
    // ...enough to surface the restful wish first
    expect(weary[0].seedId).toBe("rest");
  });
});
