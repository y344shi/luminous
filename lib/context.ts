import type { ContextSnapshot, Energy, Mood, LocationType } from "./types";
import { nowIso } from "@core/utils";
import { isLateNightHour, isWeekend, semanticTimeFromDate } from "./semanticTime";

export type ContextInput = {
  mood: Mood;
  energy: Energy;
  freeMinutes?: number;
  locationHint?: LocationType;
  isOutdoorWeatherGood?: boolean;
  now?: Date;
  isMobile?: boolean;
  isAtComputer?: boolean;
};

/** Build a ContextSnapshot from the small set of things the user tells us
 * plus device/time signals we can infer without sensitive data. */
export function buildContext(input: ContextInput): ContextSnapshot {
  const now = input.now ?? new Date();
  const weekend = isWeekend(now);
  return {
    timestamp: nowIso(),
    semanticTime: semanticTimeFromDate(now),
    mood: input.mood,
    energy: input.energy,
    freeMinutes: input.freeMinutes,
    isLateNight: isLateNightHour(now.getHours()),
    isWeekend: weekend,
    isOutdoorWeatherGood: input.isOutdoorWeatherGood,
    locationHint: input.locationHint,
    deviceContext: {
      isMobile: input.isMobile ?? false,
      isAtComputer: input.isAtComputer,
    },
  };
}
