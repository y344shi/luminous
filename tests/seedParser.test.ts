import { describe, it, expect } from "vitest";
import { parseSeedMock, draftToSeed } from "@core/seedParser";

describe("seedParser (mock)", () => {
  it("turns an outdoor wish into a small minimum action", () => {
    const draft = parseSeedMock("我想找个天气好的时候去野外坐一会，不刷手机。");
    expect(draft.categories).toContain("recovery");
    expect(draft.locationType).toBe("outdoor");
    expect(draft.minimumAction.length).toBeLessThan(30);
    expect(draft.estimatedDurationMin).toBeLessThanOrEqual(30);
  });

  it("recognizes french words wish", () => {
    const draft = parseSeedMock("我想记几个法语单词");
    expect(draft.categories).toContain("learning");
    expect(draft.energyRequired).toBe("low");
  });

  it("recognizes a code / claude wish as creation", () => {
    const draft = parseSeedMock("我不想全交给 Claude，我想亲手看懂一个模块的代码");
    expect(draft.categories).toContain("creation");
    expect(draft.locationType).toBe("computer");
  });

  it("always produces a non-empty title and minimum action", () => {
    const draft = parseSeedMock("随便写点什么模糊的东西");
    expect(draft.title.length).toBeGreaterThan(0);
    expect(draft.minimumAction.length).toBeGreaterThan(0);
  });

  it("draftToSeed yields a full active seed", () => {
    const seed = draftToSeed(parseSeedMock("我想吃一顿热饭"));
    expect(seed.id).toMatch(/^seed_/);
    expect(seed.status).toBe("active");
    expect(seed.categories).toContain("body");
  });
});
