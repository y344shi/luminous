/**
 * Time-of-day color grading for the scene — the light arc of a single day, dawn
 * to night. A soft overlay only; it never touches what's recommended. Pure.
 */

export type DayPhase = "dawn" | "morning" | "midday" | "golden" | "dusk" | "night";

export function dayPhase(hour: number): DayPhase {
  const h = ((hour % 24) + 24) % 24;
  if (h >= 5 && h < 7) return "dawn";
  if (h >= 7 && h < 11) return "morning";
  if (h >= 11 && h < 15) return "midday";
  if (h >= 15 && h < 18) return "golden";
  if (h >= 18 && h < 20) return "dusk";
  return "night";
}

/** A soft grading veil for the phase (blended over the scene). */
export function dayGradeTint(phase: DayPhase): string {
  switch (phase) {
    case "dawn":
      return "linear-gradient(180deg, rgba(255,198,176,0.22), rgba(255,224,206,0.06))";
    case "morning":
      return "linear-gradient(180deg, rgba(255,246,216,0.16), transparent 62%)";
    case "midday":
      return "linear-gradient(180deg, rgba(255,252,240,0.10), transparent 64%)";
    case "golden":
      return "linear-gradient(180deg, rgba(255,196,116,0.24), rgba(255,168,92,0.08))";
    case "dusk":
      return "linear-gradient(180deg, rgba(216,150,184,0.22), rgba(122,102,162,0.12))";
    case "night":
      return "linear-gradient(180deg, rgba(58,68,118,0.30), rgba(28,32,62,0.16))";
  }
}

export function dayGradeLabel(phase: DayPhase): string {
  return { dawn: "破晓", morning: "上午", midday: "正午", golden: "黄昏前", dusk: "黄昏", night: "夜里" }[phase];
}
