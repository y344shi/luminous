import { describe, it, expect } from "vitest";
import { isQuietNow, remindersRemaining, canRemindNow } from "@/lib/reminders";
import { defaultSettings } from "@/lib/storage";
import type { Settings } from "@core/types";

function settings(over: Partial<Settings> = {}): Settings {
  return { ...defaultSettings, ...over };
}
const at = (hour: number) => new Date(2026, 5, 25, hour, 0, 0);

describe("isQuietNow", () => {
  it("handles a window that wraps past midnight (23 → 8)", () => {
    const s = settings({ quietHoursStart: 23, quietHoursEnd: 8 });
    expect(isQuietNow(s, at(23))).toBe(true);
    expect(isQuietNow(s, at(2))).toBe(true);
    expect(isQuietNow(s, at(7))).toBe(true);
    expect(isQuietNow(s, at(8))).toBe(false); // end is exclusive
    expect(isQuietNow(s, at(12))).toBe(false);
    expect(isQuietNow(s, at(22))).toBe(false);
  });

  it("handles a same-day window (13 → 14)", () => {
    const s = settings({ quietHoursStart: 13, quietHoursEnd: 14 });
    expect(isQuietNow(s, at(13))).toBe(true);
    expect(isQuietNow(s, at(14))).toBe(false);
    expect(isQuietNow(s, at(9))).toBe(false);
  });

  it("treats start === end as no quiet window", () => {
    const s = settings({ quietHoursStart: 9, quietHoursEnd: 9 });
    expect(isQuietNow(s, at(9))).toBe(false);
    expect(isQuietNow(s, at(0))).toBe(false);
  });
});

describe("reminder budget", () => {
  it("remindersRemaining never goes negative", () => {
    const s = settings({ maxRemindersPerDay: 3 });
    expect(remindersRemaining(s, 0)).toBe(3);
    expect(remindersRemaining(s, 3)).toBe(0);
    expect(remindersRemaining(s, 5)).toBe(0);
  });

  it("canRemindNow requires non-quiet AND budget left", () => {
    const s = settings({ quietHoursStart: 23, quietHoursEnd: 8, maxRemindersPerDay: 2 });
    expect(canRemindNow(s, 0, at(12))).toBe(true); // awake + budget
    expect(canRemindNow(s, 2, at(12))).toBe(false); // budget spent
    expect(canRemindNow(s, 0, at(2))).toBe(false); // quiet hours
  });
});
