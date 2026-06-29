import { describe, it, expect } from "vitest";
import { sceneVisual } from "@/lib/sceneBackground";

const KEYS = ["desk", "grass", "highway", "cafe", "night", "home", "work", "spark"] as const;

describe("sceneVisual — wallpaper per scene", () => {
  it("returns a layered gradient for every scene key", () => {
    for (const k of KEYS) {
      const v = sceneVisual(k);
      expect(v.gradient).toContain("gradient");
      expect(v.gradient.length).toBeGreaterThan(40);
    }
  });

  it("has no curated image unless one is configured (gradient fallback)", () => {
    // NEXT_PUBLIC_SCENE_IMAGES is unset in tests → image stays undefined
    expect(sceneVisual("cafe").image).toBeUndefined();
  });
});
