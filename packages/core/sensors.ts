/**
 * Sensor fusion — derive coarse, on-device context from device senses so the
 * recommender can be keen about *which* tiny action fits right now. Pure
 * classifiers here (testable); the live sampling (accelerometer, opt-in mic)
 * happens in a client hook. NOTHING raw ever leaves the device — only the coarse
 * derived signal feeds the local ranking. Heart rate is iOS/HealthKit-only.
 */

export type Activity = "still" | "walking" | "transit";
export type Ambient = "quiet" | "lively";
export type Arousal = "calm" | "elevated";

function avg(xs: number[]): number {
  return xs.reduce((a, b) => a + b, 0) / xs.length;
}

/**
 * Classify movement from a short window of accelerometer magnitudes. We use the
 * mean absolute deviation (how much the reading jitters) as the signal: a still
 * device barely moves; walking has a steady moderate sway; a vehicle/transit
 * produces larger, more sustained variation. Needs a few samples; else undefined.
 */
export function classifyActivity(magnitudes: number[]): Activity | undefined {
  if (magnitudes.length < 4) return undefined;
  const mean = avg(magnitudes);
  const variability = avg(magnitudes.map((m) => Math.abs(m - mean)));
  if (variability < 0.6) return "still";
  if (variability < 3.5) return "walking";
  return "transit";
}

/** Classify ambient loudness from a normalized RMS level (0..1). */
export function classifyAmbient(rms: number): Ambient {
  return rms >= 0.08 ? "lively" : "quiet";
}

/** Classify arousal from a heart rate (bpm). iOS HealthKit feeds this; web won't. */
export function classifyArousal(bpm: number, resting = 70): Arousal {
  return bpm >= resting + 18 ? "elevated" : "calm";
}
