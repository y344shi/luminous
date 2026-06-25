import { describe, it, expect } from "vitest";
import {
  semanticTimeFromHour,
  isLateNightHour,
} from "@/lib/semanticTime";

describe("semanticTime", () => {
  it("maps late hours to late_night", () => {
    expect(semanticTimeFromHour(23)).toBe("late_night");
    expect(semanticTimeFromHour(2)).toBe("late_night");
    expect(semanticTimeFromHour(4)).toBe("late_night");
  });

  it("maps day hours correctly on weekdays", () => {
    expect(semanticTimeFromHour(8)).toBe("morning");
    expect(semanticTimeFromHour(12)).toBe("lunch");
    expect(semanticTimeFromHour(15)).toBe("afternoon");
    expect(semanticTimeFromHour(18)).toBe("after_work");
    expect(semanticTimeFromHour(21)).toBe("evening");
  });

  it("weekend overrides daytime label but not late night", () => {
    expect(semanticTimeFromHour(15, true)).toBe("weekend");
    expect(semanticTimeFromHour(2, true)).toBe("late_night");
  });

  it("isLateNightHour boundaries", () => {
    expect(isLateNightHour(22)).toBe(false);
    expect(isLateNightHour(23)).toBe(true);
    expect(isLateNightHour(5)).toBe(false);
    expect(isLateNightHour(4)).toBe(true);
  });
});
