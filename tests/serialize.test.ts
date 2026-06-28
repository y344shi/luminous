import { describe, it, expect } from "vitest";
import {
  deserializeSeed,
  deserializeTrace,
  deserializeSeeds,
  deserializeTraces,
} from "@/lib/serialize";
import { seedMockGarden } from "@core/mockSeeds";
import { buildTrace } from "@core/traceGenerator";

describe("serialize — seeds", () => {
  it("round-trips a real seed unchanged through JSON", () => {
    const seed = seedMockGarden()[0];
    const back = deserializeSeed(JSON.parse(JSON.stringify(seed)));
    expect(back).toEqual(seed);
  });

  it("drops records missing id or title", () => {
    expect(deserializeSeed({ title: "no id" })).toBeNull();
    expect(deserializeSeed({ id: "x", title: "  " })).toBeNull();
    expect(deserializeSeed(null)).toBeNull();
    expect(deserializeSeed("nope")).toBeNull();
  });

  it("coerces bad enum/array/number fields to safe defaults", () => {
    const s = deserializeSeed({
      id: "seed_x",
      title: "半成品",
      categories: ["bogus", "body", 5],
      preferredTimes: ["evening", "nonsense"],
      energyRequired: "ultra",
      locationType: "moon",
      estimatedDurationMin: -3,
      status: "???",
    });
    expect(s).not.toBeNull();
    expect(s!.categories).toEqual(["body"]);
    expect(s!.preferredTimes).toEqual(["evening"]);
    expect(s!.energyRequired).toBe("low");
    expect(s!.locationType).toBe("anywhere");
    expect(s!.estimatedDurationMin).toBe(10);
    expect(s!.status).toBe("active");
    expect(s!.minimumAction.length).toBeGreaterThan(0);
  });

  it("deserializeSeeds filters out the bad ones", () => {
    const good = seedMockGarden()[0];
    const list = deserializeSeeds([good, { junk: true }, null, { id: "y", title: "ok" }]);
    expect(list.length).toBe(2);
  });
});

describe("serialize — traces", () => {
  it("round-trips a real trace", () => {
    const t = buildTrace(seedMockGarden()[1], "partial");
    const back = deserializeTrace(JSON.parse(JSON.stringify(t)));
    expect(back).toEqual(t);
  });

  it("requires id, text, and date", () => {
    expect(deserializeTrace({ id: "t", text: "hi" })).toBeNull(); // no date
    expect(deserializeTrace({ id: "t", date: "2026-06-25" })).toBeNull(); // no text
    expect(deserializeTraces([{ bad: 1 }, null])).toEqual([]);
  });

  it("normalizes partial to a strict boolean", () => {
    const t = deserializeTrace({ id: "t", text: "x", date: "2026-06-25" });
    expect(t!.partial).toBe(false);
  });
});
