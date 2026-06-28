import type { Settings, Opportunity } from "./types";
import type { RemindersToday } from "./storage";
import { canRemindNow } from "./reminders";
import { localDateKey } from "@core/utils";
import { copy } from "./copy";

/**
 * Pure decision layer for gentle nudges. The UI (NudgeManager) handles
 * permission, timers, and actually showing the notification — but whether a
 * nudge is allowed *right now* lives here so it's testable and honours the same
 * quiet-hours + daily-budget rules as everything else.
 */

/** Today's reminder count (resets when the date rolls over). */
export function remindersSentToday(r: RemindersToday | null, now: Date = new Date()): number {
  const today = localDateKey(now);
  return r && r.date === today ? r.count : 0;
}

export function bumpReminders(r: RemindersToday | null, now: Date = new Date()): RemindersToday {
  const today = localDateKey(now);
  const count = r && r.date === today ? r.count + 1 : 1;
  return { date: today, count };
}

/**
 * May we gently nudge right now? Requires nudges enabled, not in quiet hours,
 * and within today's budget. (Whether the app is backgrounded is the caller's
 * concern — we don't nudge someone who's already looking at the app.)
 */
export function shouldNudge(
  settings: Settings,
  reminders: RemindersToday | null,
  now: Date = new Date()
): boolean {
  if (!settings.nudgesEnabled) return false;
  return canRemindNow(settings, remindersSentToday(reminders, now), now);
}

/** The gentle notification text for an opportunity. */
export function nudgeText(opportunity: Opportunity): { title: string; body: string } {
  return {
    title: copy.appTitle,
    body: opportunity.notificationText,
  };
}
