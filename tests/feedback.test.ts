import { describe, it, expect, vi, afterEach } from "vitest";
import { hapticComplete, chimeComplete, completeFeedback } from "@/lib/feedback";

const nav = navigator as unknown as { vibrate?: (p: number[]) => boolean };

afterEach(() => {
  vi.restoreAllMocks();
  delete nav.vibrate;
});

describe("feedback", () => {
  it("hapticComplete vibrates a gentle pattern when supported", () => {
    const vibrate = vi.fn();
    nav.vibrate = vibrate;
    hapticComplete();
    expect(vibrate).toHaveBeenCalledWith([8, 26, 14]);
  });

  it("never throws where vibration/audio are unsupported", () => {
    expect(() => hapticComplete()).not.toThrow();
    expect(() => chimeComplete()).not.toThrow(); // no AudioContext in jsdom
    expect(() => completeFeedback(true)).not.toThrow();
    expect(() => completeFeedback(false)).not.toThrow();
  });

  it("completeFeedback fires the haptic regardless of sound flag", () => {
    const vibrate = vi.fn();
    nav.vibrate = vibrate;
    completeFeedback(false);
    expect(vibrate).toHaveBeenCalled();
  });
});
