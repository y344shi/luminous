import { describe, it, expect } from "vitest";
import { render } from "@testing-library/react";
import { illustrationStyles, IllustrationArt } from "@/components/home/shared/illustrationPacks";
import type { SeedCategory } from "@core/types";

const CATEGORIES: SeedCategory[] = [
  "body",
  "creation",
  "connection",
  "exploration",
  "recovery",
  "learning",
  "aesthetic",
];
const EXPECTED_KEYS = [
  "opendoodles",
  "storyset",
  "pixeltrue",
  "blush",
  "humaaans",
  "openpeeps",
  "undraw",
  "drawkit",
];

describe("illustration packs", () => {
  it("registers all 8 library packs, each with a name + signature art", () => {
    expect([...illustrationStyles.map((p) => p.key)].sort()).toEqual([...EXPECTED_KEYS].sort());
    for (const p of illustrationStyles) {
      expect(p.name).toBeTruthy();
      expect(p.note).toBeTruthy();
      expect(p.art).toBeTruthy();
    }
  });

  it("every pack is category-aware — a scene for all 7 wish categories", () => {
    for (const p of illustrationStyles) {
      expect(typeof p.scene).toBe("function");
      for (const c of CATEGORIES) {
        expect(p.scene!(c)).toBeTruthy();
      }
    }
  });

  it("IllustrationArt renders an svg per category, and falls back for an unknown style", () => {
    const { container } = render(<IllustrationArt style="storyset" category="learning" />);
    expect(container.querySelector("svg")).toBeTruthy();
    // unknown style → falls back to the first pack's signature art (still renders)
    const { container: c2 } = render(<IllustrationArt style="nope" />);
    expect(c2.querySelector("svg")).toBeTruthy();
  });
});
