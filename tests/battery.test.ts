import { describe, it, expect } from "vitest";
import { isBatteryLow } from "@core/battery";
import { batteryBonus } from "@core/scoring";
import type { Seed, ContextSnapshot } from "@core/types";

describe("battery model", () => {
  it("low only when below 20% and unplugged", () => {
    expect(isBatteryLow(0.15, false)).toBe(true);
    expect(isBatteryLow(0.15, true)).toBe(false); // charging
    expect(isBatteryLow(0.5, false)).toBe(false); // plenty
    expect(isBatteryLow(0.2, false)).toBe(true); // at threshold
  });
});

const seed = (over: Partial<Seed>): Seed => ({
  id: "s", rawText: "", title: "t", categories: ["creation"], minimumAction: "",
  estimatedDurationMin: 30, energyRequired: "medium", locationType: "computer",
  preferredTimes: [], triggerConditions: [], status: "active",
  createdAt: "", updatedAt: "", ...over,
});
const ctx = (batteryLow?: boolean): ContextSnapshot => ({
  timestamp: "", semanticTime: "afternoon", mood: "unknown", energy: "medium",
  isLateNight: false, batteryLow,
});

describe("batteryBonus", () => {
  it("does nothing unless low + unplugged", () => {
    expect(batteryBonus(seed({}), ctx(undefined))).toBe(0);
    expect(batteryBonus(seed({ categories: ["recovery"] }), ctx(false))).toBe(0);
  });
  it("when low, favors small/restful and eases off long/high-energy", () => {
    expect(batteryBonus(seed({ categories: ["recovery"], estimatedDurationMin: 5 }), ctx(true))).toBeGreaterThan(0);
    expect(batteryBonus(seed({ energyRequired: "high", estimatedDurationMin: 60 }), ctx(true))).toBeLessThan(0);
  });
  it("stays capped", () => {
    const b = batteryBonus(seed({ categories: ["recovery", "body"], estimatedDurationMin: 5 }), ctx(true));
    expect(Math.abs(b)).toBeLessThanOrEqual(0.12);
  });
});
