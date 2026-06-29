import { describe, it, expect } from "vitest";
import { dayPhase, dayGradeTint, dayGradeLabel } from "@/lib/dayGrade";

describe("dayGrade", () => {
  it("maps the hour to the right phase across the day", () => {
    expect(dayPhase(6)).toBe("dawn");
    expect(dayPhase(9)).toBe("morning");
    expect(dayPhase(13)).toBe("midday");
    expect(dayPhase(16)).toBe("golden");
    expect(dayPhase(19)).toBe("dusk");
    expect(dayPhase(23)).toBe("night");
    expect(dayPhase(2)).toBe("night");
  });

  it("handles out-of-range hours safely", () => {
    expect(dayPhase(24)).toBe("night"); // wraps to 0
    expect(dayPhase(-1)).toBe("night"); // wraps to 23
  });

  it("every phase has a gradient tint and a zh label", () => {
    for (const p of ["dawn", "morning", "midday", "golden", "dusk", "night"] as const) {
      expect(dayGradeTint(p)).toContain("gradient");
      expect(dayGradeLabel(p).length).toBeGreaterThan(0);
    }
  });
});
