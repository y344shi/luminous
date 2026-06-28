import type {
  Seed,
  ContextSnapshot,
  Opportunity,
  Energy,
  Mood,
  SeedCategory,
} from "./types";
import { uid, nowIso, clamp } from "./utils";

const energyRank: Record<Energy, number> = { low: 0, medium: 1, high: 2 };

// Which categories each mood gently leans toward.
const moodAffinity: Record<Mood, SeedCategory[]> = {
  empty: ["recovery", "connection", "body", "aesthetic"],
  tired: ["body", "recovery"],
  anxious: ["body", "recovery", "exploration"],
  okay: ["learning", "creation", "exploration", "aesthetic"],
  alive: ["exploration", "aesthetic", "creation"],
  avoidant: ["creation", "learning"],
  lonely: ["connection", "recovery", "body"],
  want_love: ["connection", "recovery", "body"],
  unknown: [],
};

export type ScoreBreakdown = {
  timeFit: number;
  durationFit: number;
  energyFit: number;
  locationFit: number;
  moodFit: number;
  freshness: number;
  serendipity: number;
  total: number;
};

export type ScoredSeed = {
  seed: Seed;
  breakdown: ScoreBreakdown;
  reason: string;
  suggestedAction: string;
};

type Rng = () => number;

function timeFit(seed: Seed, ctx: ContextSnapshot): number {
  if (seed.preferredTimes.length === 0) return 0.6;
  if (seed.preferredTimes.includes(ctx.semanticTime)) return 1;
  // weekend acts as a soft wildcard for relaxed seeds
  if (ctx.isWeekend && seed.preferredTimes.includes("weekend")) return 1;
  return 0.3;
}

function durationFit(seed: Seed, ctx: ContextSnapshot): number {
  if (ctx.freeMinutes == null) return 0.6; // unknown — stay neutral
  const free = ctx.freeMinutes;
  if (free >= seed.estimatedDurationMin) return 1;
  // The minimum action is always smaller than the full estimate.
  if (free >= seed.estimatedDurationMin / 3) return 0.65;
  if (free >= 5) return 0.35;
  return 0.1;
}

function energyFit(seed: Seed, ctx: ContextSnapshot): number {
  const need = energyRank[seed.energyRequired];
  const have = energyRank[ctx.energy];
  if (have >= need) return 1;
  if (need - have === 1) return 0.4;
  return 0.1;
}

function locationFit(seed: Seed, ctx: ContextSnapshot): number {
  if (seed.locationType === "anywhere") return 1;
  const hint = ctx.locationHint;
  if (!hint || hint === "unknown") {
    // We can't confirm — be optimistic for indoor/computer, cautious for far places.
    if (seed.locationType === "downtown" || seed.locationType === "outdoor") return 0.45;
    return 0.6;
  }
  if (hint === seed.locationType) return 1;
  // computer is usually at home; treat as compatible
  if (seed.locationType === "computer" && hint === "home") return 0.8;
  if (seed.locationType === "home" && hint === "computer") return 0.8;
  return 0.2;
}

function moodFit(seed: Seed, ctx: ContextSnapshot): number {
  const prefs = moodAffinity[ctx.mood] ?? [];
  if (prefs.length === 0) return 0.6;
  const overlap = seed.categories.some((c) => prefs.includes(c));
  return overlap ? 1 : 0.3;
}

function freshness(seed: Seed): number {
  if (seed.status === "sleeping") return 0.5;
  if (seed.status === "active") return 1;
  return 0;
}

/**
 * Additive bonus when a seed's trigger conditions match the live context.
 * This lets intent-tagged seeds (e.g. "avoidant_mood", "rescue_mode") rise
 * to the top when the moment actually calls for them. Capped so it nudges
 * rather than dominates.
 */
export function triggerBonus(seed: Seed, ctx: ContextSnapshot): number {
  let bonus = 0;
  const has = (t: string) => seed.triggerConditions.includes(t);
  const short = ctx.freeMinutes != null && ctx.freeMinutes <= 15;

  if (has("avoidant_mood") && ctx.mood === "avoidant") bonus += 0.18;
  if (has("lonely") && ctx.mood === "lonely") bonus += 0.18;
  if (has("want_love") && (ctx.mood === "want_love" || ctx.mood === "lonely")) bonus += 0.18;
  if (has("low_energy_ok") && ctx.energy === "low") bonus += 0.06;
  if (has("short_free_time") && short) bonus += 0.08;
  if (has("free_time_15min") && ctx.freeMinutes != null && ctx.freeMinutes >= 15) bonus += 0.04;
  if (has("weather_good") && ctx.isOutdoorWeatherGood) bonus += 0.1;
  if (has("near_outdoor") && ctx.locationHint === "outdoor") bonus += 0.1;
  if (has("at_computer") && ctx.deviceContext?.isAtComputer) bonus += 0.06;
  if ((has("late_night") || has("rescue_mode")) && ctx.isLateNight) bonus += 0.2;
  if (has("not_late_night") && ctx.isLateNight) bonus -= 0.3;

  return bonus;
}

/**
 * Additive nudge from the fused device senses (motion / ambient loudness / heart
 * rate). Each signal is optional — absent ones do nothing. Soft by design and
 * capped, so it shapes the ranking without overpowering fit/mood/triggers.
 */
export function sensorBonus(seed: Seed, ctx: ContextSnapshot): number {
  let b = 0;
  const has = (c: SeedCategory) => seed.categories.includes(c);
  const focus = has("learning") || has("creation");

  // Motion / activity.
  if (ctx.activity === "transit") {
    if (seed.estimatedDurationMin <= 10) b += 0.1; // quick things suit the move
    if (focus && seed.locationType === "computer") b -= 0.12; // not now
    if (has("recovery") || has("body")) b += 0.05;
  } else if (ctx.activity === "walking") {
    if (seed.locationType === "outdoor" || has("exploration") || has("body")) b += 0.1;
  } else if (ctx.activity === "still") {
    if (focus) b += 0.05;
  }

  // Ambient loudness.
  if (ctx.ambient === "quiet") {
    if (focus || has("aesthetic")) b += 0.1;
  } else if (ctx.ambient === "lively") {
    if (has("connection")) b += 0.1;
    if (has("recovery")) b += 0.05; // step out of the noise
    if (focus) b -= 0.06;
  }

  // Arousal (heart rate; iOS-fed).
  if (ctx.arousal === "elevated") {
    if (has("recovery") || has("body")) b += 0.12;
    if (seed.energyRequired === "high" || has("exploration")) b -= 0.08;
  } else if (ctx.arousal === "calm") {
    if (focus) b += 0.06;
  }

  return clamp(b, -0.25, 0.25);
}

/**
 * Late-night safety gate. Returns true if this seed is UNSAFE to recommend
 * late at night (too big, requires going out, or high energy).
 */
export function isUnsafeLateNight(seed: Seed): boolean {
  if (seed.triggerConditions.includes("late_night") || seed.triggerConditions.includes("rescue_mode")) {
    return false; // explicit rescue seeds are always allowed
  }
  if (seed.locationType === "outdoor" || seed.locationType === "downtown") return true;
  if (seed.categories.includes("exploration")) return true;
  if (seed.energyRequired === "high") return true;
  if (seed.estimatedDurationMin > 20) return true;
  return false;
}

function isRescueSeed(seed: Seed): boolean {
  return (
    seed.triggerConditions.includes("late_night") ||
    seed.triggerConditions.includes("rescue_mode") ||
    (seed.energyRequired === "low" &&
      seed.estimatedDurationMin <= 15 &&
      seed.categories.some((c) => c === "body" || c === "recovery"))
  );
}

const semanticTimeLabel: Record<string, string> = {
  morning: "早上",
  lunch: "中午",
  afternoon: "下午",
  after_work: "傍晚",
  evening: "晚上",
  late_night: "深夜",
  weekend: "周末",
};

function buildReason(seed: Seed, ctx: ContextSnapshot, b: ScoreBreakdown): string {
  if (ctx.isLateNight) {
    return "现在已经很晚了，这是一个不费力的止损动作。完成它，今天就没有完全消失。";
  }
  const bits: string[] = [];
  if (b.durationFit >= 0.9 && ctx.freeMinutes != null) {
    bits.push(`你现在大概有 ${ctx.freeMinutes} 分钟，刚好够`);
  } else if (ctx.energy === "low") {
    bits.push("你现在不需要很大力气，只要离开屏幕一会儿");
  }
  if (b.moodFit >= 0.9) {
    if (ctx.mood === "lonely" || ctx.mood === "want_love") bits.push("它能让你和世界重新有一点连接");
    else if (ctx.mood === "anxious") bits.push("它能让你慢下来一点");
    else if (ctx.mood === "empty") bits.push("它能让你重新有一点在场的感觉");
    else if (ctx.mood === "avoidant") bits.push("它很小，小到可以现在就开始");
  }
  if (bits.length === 0) {
    const tl = semanticTimeLabel[ctx.semanticTime] ?? "现在";
    bits.push(`${tl}刚好适合做一点点`);
  }
  return bits.join("，") + "。";
}

export function scoreSeed(
  seed: Seed,
  ctx: ContextSnapshot,
  rng: Rng = Math.random
): ScoreBreakdown {
  const tf = timeFit(seed, ctx);
  const df = durationFit(seed, ctx);
  const ef = energyFit(seed, ctx);
  const lf = locationFit(seed, ctx);
  const mf = moodFit(seed, ctx);
  const fr = freshness(seed);
  const ser = rng();

  let total =
    tf * 0.2 + df * 0.2 + ef * 0.2 + lf * 0.2 + mf * 0.1 + fr * 0.05 + ser * 0.05;

  total += triggerBonus(seed, ctx);
  total += sensorBonus(seed, ctx);

  // Late-night reshaping happens in recommend(), but reflect rescue boost here too.
  if (ctx.isLateNight && isRescueSeed(seed)) {
    total += 0.5;
  }

  return {
    timeFit: tf,
    durationFit: df,
    energyFit: ef,
    locationFit: lf,
    moodFit: mf,
    freshness: fr,
    serendipity: ser,
    total: clamp(total, 0, 2),
  };
}

export type RecommendOptions = {
  rng?: Rng;
  limit?: number;
};

/** Rank active seeds for the current context and return scored candidates. */
export function rankSeeds(
  seeds: Seed[],
  ctx: ContextSnapshot,
  opts: RecommendOptions = {}
): ScoredSeed[] {
  const rng = opts.rng ?? Math.random;
  const limit = opts.limit ?? 3;

  let candidates = seeds.filter((s) => s.status === "active" || s.status === "sleeping");

  if (ctx.isLateNight) {
    // Hard safety gate: drop anything unsafe; if rescue seeds exist, keep only safe ones.
    const safe = candidates.filter((s) => !isUnsafeLateNight(s));
    candidates = safe.length > 0 ? safe : candidates;
  }

  const scored = candidates.map((seed) => {
    const breakdown = scoreSeed(seed, ctx, rng);
    return {
      seed,
      breakdown,
      reason: buildReason(seed, ctx, breakdown),
      suggestedAction: seed.minimumAction,
    };
  });

  scored.sort((a, b) => b.breakdown.total - a.breakdown.total);
  return scored.slice(0, limit);
}

/** Convert scored seeds into Opportunity records ready for the UI. */
export function recommend(
  seeds: Seed[],
  ctx: ContextSnapshot,
  opts: RecommendOptions = {}
): Opportunity[] {
  return rankSeeds(seeds, ctx, opts).map((s) => ({
    id: uid("opp"),
    seedId: s.seed.id,
    score: s.breakdown.total,
    reason: s.reason,
    suggestedAction: s.suggestedAction,
    notificationText: `${s.seed.title} · ${s.seed.minimumAction}`,
    createdAt: nowIso(),
  }));
}
