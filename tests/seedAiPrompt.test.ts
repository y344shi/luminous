import { describe, it, expect } from "vitest";
import { parseModelDraft, SEED_PARSER_SYSTEM_PROMPT } from "@core/seedAiPrompt";

const RAW = "我想找个天气好的时候坐一会野外";

describe("parseModelDraft", () => {
  it("accepts a well-formed model JSON object", () => {
    const draft = parseModelDraft(
      {
        title: "坐一会野外",
        minimumAction: "在户外坐 10 分钟，不刷手机",
        categories: ["recovery", "exploration"],
        estimatedDurationMin: 15,
        energyRequired: "low",
        locationType: "outdoor",
        preferredTimes: ["afternoon"],
        triggerConditions: ["weather_good"],
      },
      RAW
    );
    expect(draft).not.toBeNull();
    expect(draft!.title).toBe("坐一会野外");
    expect(draft!.rawText).toBe(RAW);
    expect(draft!.categories).toEqual(["recovery", "exploration"]);
  });

  it("extracts JSON even when wrapped in prose / code fences", () => {
    const text = "好的，这是结果：\n```json\n{\"title\":\"喝口水\",\"minimumAction\":\"喝几口水\"}\n```";
    const draft = parseModelDraft(text, RAW);
    expect(draft).not.toBeNull();
    expect(draft!.title).toBe("喝口水");
    // bad/missing enums coerced to safe defaults
    expect(draft!.energyRequired).toBe("low");
    expect(draft!.categories).toEqual(["recovery"]);
  });

  it("rejects when title or minimumAction is missing", () => {
    expect(parseModelDraft({ title: "只有标题" }, RAW)).toBeNull();
    expect(parseModelDraft({ minimumAction: "只有动作" }, RAW)).toBeNull();
    expect(parseModelDraft("no json here", RAW)).toBeNull();
    expect(parseModelDraft(null, RAW)).toBeNull();
  });

  it("filters bogus categories/times and clamps duration", () => {
    const draft = parseModelDraft(
      {
        title: "x",
        minimumAction: "y",
        categories: ["bogus", "body"],
        preferredTimes: ["nope", "evening"],
        estimatedDurationMin: -5,
      },
      RAW
    )!;
    expect(draft.categories).toEqual(["body"]);
    expect(draft.preferredTimes).toEqual(["evening"]);
    expect(draft.estimatedDurationMin).toBe(10);
  });

  it("system prompt forbids todo/shame framing", () => {
    expect(SEED_PARSER_SYSTEM_PROMPT).toMatch(/不要像任务|不要.*愧疚|做一点也算/);
  });
});
