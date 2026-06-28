import type { ContextSnapshot, Mood, Energy } from "@core/types";
import { seedMockGarden } from "@/lib/mockSeeds";

export const fixedRng = () => 0.5;

export function ctx(over: Partial<ContextSnapshot> = {}): ContextSnapshot {
  return {
    timestamp: "2026-06-25T12:00:00.000Z",
    semanticTime: "afternoon",
    mood: "okay" as Mood,
    energy: "medium" as Energy,
    isLateNight: false,
    isWeekend: false,
    ...over,
  };
}

export const garden = seedMockGarden;
