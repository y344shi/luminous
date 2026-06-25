import type { SemanticTime } from "./types";

/**
 * Map a clock hour (and weekend flag) to a semantic time-of-day.
 * Late night is the protected window: 23:00–04:59.
 */
export function semanticTimeFromHour(hour: number, isWeekend = false): SemanticTime {
  if (hour >= 23 || hour < 5) return "late_night";
  if (isWeekend) return "weekend";
  if (hour < 11) return "morning";
  if (hour < 14) return "lunch";
  if (hour < 17) return "afternoon";
  if (hour < 19) return "after_work";
  return "evening";
}

export function isLateNightHour(hour: number): boolean {
  return hour >= 23 || hour < 5;
}

export function isWeekend(date: Date = new Date()): boolean {
  const d = date.getDay();
  return d === 0 || d === 6;
}

/** Derive semantic time from a concrete Date, honoring weekends. */
export function semanticTimeFromDate(date: Date = new Date()): SemanticTime {
  return semanticTimeFromHour(date.getHours(), isWeekend(date));
}
