import { describe, it, expect } from "vitest";
import { guessLocation, ambientLabel, buildAmbientContext, isWorkday, orbScene } from "@/lib/ambient";

// 2026-06-24 is a Wednesday; 2026-06-27 is a Saturday.
const wedAfternoon = new Date(2026, 5, 24, 15, 0, 0);
const wedEvening = new Date(2026, 5, 24, 21, 0, 0);
const satLunch = new Date(2026, 5, 27, 12, 30, 0);
const wedLateNight = new Date(2026, 5, 24, 1, 0, 0);

describe("ambient — location guess", () => {
  it("desktop is read as 'at a computer'", () => {
    expect(guessLocation(wedAfternoon, false)).toBe("computer");
    expect(guessLocation(satLunch, false)).toBe("computer");
  });
  it("mobile in the evening/morning/late-night guesses home", () => {
    expect(guessLocation(wedEvening, true)).toBe("home");
    expect(guessLocation(wedLateNight, true)).toBe("home");
  });
  it("mobile midday is left open (anywhere)", () => {
    expect(guessLocation(satLunch, true)).toBe("anywhere");
  });
});

describe("ambient — human label", () => {
  it("reads weekday · time · place, keeping time-of-day on weekends", () => {
    expect(ambientLabel(wedAfternoon, "computer")).toBe("周三 · 下午 · 在电脑前");
    expect(ambientLabel(satLunch, "home")).toBe("周六 · 午休时间 · 在家");
    expect(ambientLabel(wedEvening, "home")).toBe("周三 · 晚上 · 在家");
  });
  it("omits an empty/unknown place", () => {
    expect(ambientLabel(wedAfternoon, "anywhere")).toBe("周三 · 下午");
  });
});

describe("ambient — orb scene (visible AI read of the situation)", () => {
  it("maps the sensed place to a glowing scene + label", () => {
    expect(orbScene("computer", wedAfternoon)).toEqual({ glyph: "🖥️", label: "在电脑前" });
    expect(orbScene("outdoor", wedAfternoon)).toEqual({ glyph: "🌿", label: "野外" });
    expect(orbScene("transit", wedAfternoon)).toEqual({ glyph: "🛣️", label: "在路上" });
    expect(orbScene("downtown", wedAfternoon)).toEqual({ glyph: "☕", label: "街区" });
  });
  it("late night softens home + unknown into a moon", () => {
    expect(orbScene("home", wedLateNight)).toEqual({ glyph: "🌙", label: "夜里 · 在家" });
    expect(orbScene("anywhere", wedLateNight)).toEqual({ glyph: "🌙", label: "夜里" });
    expect(orbScene("home", wedEvening)).toEqual({ glyph: "🛋️", label: "在家" });
  });
});

describe("ambient — workday + context", () => {
  it("isWorkday distinguishes weekday from weekend", () => {
    expect(isWorkday(wedAfternoon)).toBe(true);
    expect(isWorkday(satLunch)).toBe(false);
  });
  it("buildAmbientContext fills mood=unknown and carries the sensed signals", () => {
    const ctx = buildAmbientContext({ now: wedLateNight, isMobile: true, locationHint: "home" });
    expect(ctx.mood).toBe("unknown");
    expect(ctx.isLateNight).toBe(true);
    expect(ctx.semanticTime).toBe("late_night");
    expect(ctx.locationHint).toBe("home");
  });
  it("at-computer flag is derived from the location guess", () => {
    const ctx = buildAmbientContext({ now: wedAfternoon, isMobile: false, locationHint: "computer" });
    expect(ctx.deviceContext?.isAtComputer).toBe(true);
  });
});
