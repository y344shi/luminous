import { describe, it, expect } from "vitest";
import { classifyActivity, classifyAmbient, classifyArousal } from "@core/sensors";
import { sensorBonus } from "@/lib/scoring";
import type { Seed, ContextSnapshot } from "@/lib/types";

describe("sensors — pure classifiers", () => {
  it("classifyActivity: still / walking / transit by variability", () => {
    expect(classifyActivity([9.8, 9.81, 9.79, 9.8, 9.8])).toBe("still");
    expect(classifyActivity([9, 11, 8.5, 11.5, 9])).toBe("walking");
    expect(classifyActivity([2, 18, 1, 20, 5, 16])).toBe("transit");
    expect(classifyActivity([9.8, 9.8])).toBeUndefined(); // too few samples
  });
  it("classifyAmbient: quiet below threshold, lively above", () => {
    expect(classifyAmbient(0.02)).toBe("quiet");
    expect(classifyAmbient(0.2)).toBe("lively");
  });
  it("classifyArousal: elevated when well above resting", () => {
    expect(classifyArousal(72)).toBe("calm");
    expect(classifyArousal(95)).toBe("elevated");
  });
});

const seed = (over: Partial<Seed>): Seed => ({
  id: "s", rawText: "", title: "t", categories: ["creation"], minimumAction: "",
  estimatedDurationMin: 30, energyRequired: "medium", locationType: "computer",
  preferredTimes: [], triggerConditions: [], status: "active",
  createdAt: "", updatedAt: "", ...over,
});
const ctx = (over: Partial<ContextSnapshot>): ContextSnapshot => ({
  timestamp: "", semanticTime: "afternoon", mood: "unknown", energy: "medium",
  isLateNight: false, ...over,
});

describe("sensorBonus — fused signals shape the ranking", () => {
  it("does nothing when no sensor signals are present", () => {
    expect(sensorBonus(seed({}), ctx({}))).toBe(0);
  });
  it("in transit: penalizes computer-focus work, rewards quick/recovery", () => {
    const focusAtComputer = seed({ categories: ["learning"], locationType: "computer", estimatedDurationMin: 40 });
    const quickBody = seed({ categories: ["body"], locationType: "anywhere", estimatedDurationMin: 5 });
    expect(sensorBonus(focusAtComputer, ctx({ activity: "transit" }))).toBeLessThan(0);
    expect(sensorBonus(quickBody, ctx({ activity: "transit" }))).toBeGreaterThan(0);
  });
  it("quiet boosts focus; lively boosts connection", () => {
    const focus = seed({ categories: ["learning"] });
    const connect = seed({ categories: ["connection"] });
    expect(sensorBonus(focus, ctx({ ambient: "quiet" }))).toBeGreaterThan(0);
    expect(sensorBonus(connect, ctx({ ambient: "lively" }))).toBeGreaterThan(0);
    expect(sensorBonus(focus, ctx({ ambient: "lively" }))).toBeLessThan(0);
  });
  it("elevated arousal favors recovery over high-energy exploration", () => {
    const recover = seed({ categories: ["recovery"] });
    const explore = seed({ categories: ["exploration"], energyRequired: "high" });
    expect(sensorBonus(recover, ctx({ arousal: "elevated" }))).toBeGreaterThan(0);
    expect(sensorBonus(explore, ctx({ arousal: "elevated" }))).toBeLessThan(0);
  });
  it("stays capped (never overpowers core fit)", () => {
    const s = seed({ categories: ["recovery", "body"] });
    const b = sensorBonus(s, ctx({ activity: "transit", ambient: "lively", arousal: "elevated" }));
    expect(Math.abs(b)).toBeLessThanOrEqual(0.25);
  });
});
