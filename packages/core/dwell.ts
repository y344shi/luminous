/**
 * Dwell — a temporal sense: how long you've been *actively at the desk today*.
 * Accumulated on-device (localStorage, per day); nothing leaves the device. It lets
 * the recommender be kinder as the day wears on — after a long sit, it leans toward
 * the body, rest, and stepping outside instead of one more screen task.
 *
 * (Web can only see THIS app's active time at a computer. System-wide app usage is
 * an iOS Screen Time capability — see docs/ios-sensor-port.md.)
 */
export type DwellLevel = "fresh" | "settled" | "long";

export type DwellRecord = { date: string; deskMs: number };

/** Coarse buckets from minutes-at-desk-today. */
export function dwellLevel(minutes: number): DwellLevel {
  if (minutes < 45) return "fresh";
  if (minutes < 120) return "settled";
  return "long";
}

/**
 * Fold an elapsed interval into today's record. Counts the interval only when at the
 * desk and the gap is plausibly continuous (a long gap means the tab slept / you left,
 * so we don't count it). Resets on a new day.
 */
export function advanceDwell(
  rec: DwellRecord | null,
  today: string,
  elapsedMs: number,
  atDesk: boolean
): DwellRecord {
  const base = rec && rec.date === today ? rec : { date: today, deskMs: 0 };
  if (atDesk && elapsedMs > 0 && elapsedMs < 5 * 60_000) {
    return { date: today, deskMs: base.deskMs + elapsedMs };
  }
  return { date: base.date, deskMs: base.deskMs };
}
