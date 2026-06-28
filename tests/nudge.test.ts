import { describe, it, expect } from "vitest";
import { shouldNudge, remindersSentToday, bumpReminders, nudgeText } from "@/lib/nudge";
import { defaultSettings } from "@/lib/storage";
import type { Settings, Opportunity } from "@core/types";

function settings(over: Partial<Settings> = {}): Settings {
  return { ...defaultSettings, ...over };
}
const at = (h: number) => new Date(2026, 5, 25, h, 0, 0);

describe("nudge — daily count", () => {
  it("counts only today, resets across the date line", () => {
    expect(remindersSentToday(null, at(12))).toBe(0);
    expect(remindersSentToday({ date: "2026-06-25", count: 2 }, at(12))).toBe(2);
    expect(remindersSentToday({ date: "2026-06-24", count: 9 }, at(12))).toBe(0);
  });
  it("bumpReminders increments today / starts fresh on a new day", () => {
    expect(bumpReminders(null, at(12))).toEqual({ date: "2026-06-25", count: 1 });
    expect(bumpReminders({ date: "2026-06-25", count: 1 }, at(12))).toEqual({ date: "2026-06-25", count: 2 });
    expect(bumpReminders({ date: "2026-06-24", count: 5 }, at(12))).toEqual({ date: "2026-06-25", count: 1 });
  });
});

describe("nudge — shouldNudge gate", () => {
  it("off unless explicitly enabled", () => {
    expect(shouldNudge(settings({ nudgesEnabled: false }), null, at(12))).toBe(false);
    expect(shouldNudge(settings({ nudgesEnabled: true }), null, at(12))).toBe(true);
  });
  it("respects quiet hours", () => {
    const s = settings({ nudgesEnabled: true, quietHoursStart: 23, quietHoursEnd: 8 });
    expect(shouldNudge(s, null, at(2))).toBe(false); // quiet
    expect(shouldNudge(s, null, at(12))).toBe(true); // awake
  });
  it("respects the daily budget", () => {
    const s = settings({ nudgesEnabled: true, maxRemindersPerDay: 2 });
    expect(shouldNudge(s, { date: "2026-06-25", count: 2 }, at(12))).toBe(false);
    expect(shouldNudge(s, { date: "2026-06-25", count: 1 }, at(12))).toBe(true);
  });
});

describe("nudge — text", () => {
  it("uses the opportunity's notification text as the body", () => {
    const opp = { notificationText: "坐一会野外 · 在户外坐 10 分钟" } as Opportunity;
    const { title, body } = nudgeText(opp);
    expect(title).toBe("今天别消失");
    expect(body).toContain("坐一会野外");
  });
});
