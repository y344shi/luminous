import { describe, it, expect } from "vitest";
import { illustrationCategory, distinctIllustrationCategory } from "@core/illustration";
import type { SeedCategory } from "@core/types";

describe("illustrationCategory", () => {
  it("returns the only category for a single-category wish", () => {
    expect(illustrationCategory(["learning"], "a")).toBe("learning");
  });
  it("is stable per key and stays within the wish's categories", () => {
    const cats: SeedCategory[] = ["creation", "learning"];
    const a = illustrationCategory(cats, "seed-1");
    expect(a).toBe(illustrationCategory(cats, "seed-1")); // deterministic
    expect(cats).toContain(a);
  });
  it("distinct pick prefers a category not already used", () => {
    const used = new Set<SeedCategory>();
    const cats: SeedCategory[] = ["creation", "learning"];
    const a = distinctIllustrationCategory(cats, "x", used);
    const b = distinctIllustrationCategory(cats, "y", used);
    expect(a).not.toBe(b); // two creation+learning wishes get different looks
  });
});
