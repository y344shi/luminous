import type { Settings } from "@core/types";

/**
 * Whether the current moment falls inside the user's quiet window.
 * Hour-granular (settings are hours). Handles windows that wrap past
 * midnight (e.g. 23 → 8). start === end means "no quiet hours".
 *
 * Quiet means: the app must not push a reminder. It never blocks the user
 * from opening the app themselves.
 */
export function isQuietNow(settings: Settings, now: Date = new Date()): boolean {
  const { quietHoursStart: start, quietHoursEnd: end } = settings;
  if (start === end) return false; // no quiet window configured
  const h = now.getHours();
  if (start < end) return h >= start && h < end; // same-day window
  return h >= start || h < end; // wraps past midnight
}

/** How many gentle reminders are still allowed today. */
export function remindersRemaining(settings: Settings, sentToday: number): number {
  return Math.max(0, settings.maxRemindersPerDay - Math.max(0, sentToday));
}

/**
 * The full gate for "may the app gently nudge right now?":
 * not in quiet hours AND still within today's small budget.
 */
export function canRemindNow(
  settings: Settings,
  sentToday: number,
  now: Date = new Date()
): boolean {
  return !isQuietNow(settings, now) && remindersRemaining(settings, sentToday) > 0;
}
