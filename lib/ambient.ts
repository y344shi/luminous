import type { ContextSnapshot, LocationType, Energy } from "./types";
import { buildContext } from "./context";
import { semanticTimeFromHour, isWeekend } from "./semanticTime";

/**
 * Ambient context: what the app can sense on its own when you open Home —
 * time of day, weekday/weekend, and whether you're at a computer — with no
 * permission prompt. Location is a guess you can correct in one tap; movement
 * is opt-in (geolocation). Everything stays on-device.
 */

export type AmbientInputs = {
  now: Date;
  isMobile: boolean;
  /** The (possibly user-corrected) location hint. */
  locationHint: LocationType;
  energy?: Energy;
  isOutdoorWeatherGood?: boolean;
};

/** Build a full ContextSnapshot for the recommender from ambient signals.
 * Mood is unknown here (we didn't ask) — the bubbles are a gentle guess. */
export function buildAmbientContext(i: AmbientInputs): ContextSnapshot {
  return buildContext({
    mood: "unknown",
    energy: i.energy ?? "medium",
    locationHint: i.locationHint,
    isAtComputer: i.locationHint === "computer",
    isMobile: i.isMobile,
    isOutdoorWeatherGood: i.isOutdoorWeatherGood,
    now: i.now,
  });
}

/**
 * A first guess at where you are, from time + device. Desktop is the one
 * strong signal (you're literally at a computer). Otherwise a soft guess the
 * user can correct.
 */
export function guessLocation(now: Date, isMobile: boolean): LocationType {
  if (!isMobile) return "computer";
  const t = semanticTimeFromHour(now.getHours(), false);
  if (t === "morning" || t === "evening" || t === "late_night") return "home";
  return "anywhere";
}

const WEEKDAY = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];

const TIME_LABEL: Record<string, string> = {
  morning: "早上",
  lunch: "午休时间",
  afternoon: "下午",
  after_work: "傍晚",
  evening: "晚上",
  late_night: "深夜",
};

const LOCATION_LABEL: Record<LocationType, string> = {
  home: "在家",
  work: "在公司",
  computer: "在电脑前",
  outdoor: "在外面",
  downtown: "在市中心",
  transit: "在路上",
  anywhere: "",
  unknown: "",
};

/** A short, human sentence describing the sensed moment, e.g.
 * "周三 · 下午 · 在电脑前" or "周六 · 晚上 · 在家". */
export function ambientLabel(now: Date, locationHint: LocationType): string {
  const wd = WEEKDAY[now.getDay()];
  // Time of day ignoring the weekend override, so we still say "下午" on Sat.
  const t = semanticTimeFromHour(now.getHours(), false);
  const parts = [wd, TIME_LABEL[t] ?? ""];
  const loc = LOCATION_LABEL[locationHint];
  if (loc) parts.push(loc);
  return parts.filter(Boolean).join(" · ");
}

/** Is today a weekday? (helper for callers/tests) */
export function isWorkday(now: Date): boolean {
  return !isWeekend(now);
}
