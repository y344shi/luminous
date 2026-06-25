import type {
  Seed,
  DailyTrace,
  SeedCategory,
  Energy,
  LocationType,
  SemanticTime,
  SeedStatus,
} from "./types";

/**
 * DB-agnostic (de)serialization boundary. The same plain-record shape works
 * for localStorage (Phase 1) and a Prisma/Postgres adapter (Phase 2) — see
 * prisma/schema.prisma. Deserialization VALIDATES + coerces, returning null
 * for records too malformed to trust, so a corrupt entry can never crash the
 * garden or the journal.
 */

const CATEGORIES: SeedCategory[] = [
  "body", "creation", "connection", "exploration", "recovery", "learning", "aesthetic",
];
const ENERGIES: Energy[] = ["low", "medium", "high"];
const LOCATIONS: LocationType[] = [
  "anywhere", "home", "work", "outdoor", "downtown", "computer", "transit", "unknown",
];
const TIMES: SemanticTime[] = [
  "morning", "lunch", "afternoon", "after_work", "evening", "late_night", "weekend", "transit",
];
const STATUSES: SeedStatus[] = ["active", "sleeping", "completed", "archived"];

const str = (v: unknown): v is string => typeof v === "string";
function strArray(v: unknown): string[] {
  return Array.isArray(v) ? v.filter(str) : [];
}
function oneOf<T extends string>(v: unknown, allowed: T[], fallback: T): T {
  return str(v) && (allowed as string[]).includes(v) ? (v as T) : fallback;
}

/** Validate + coerce an unknown record into a Seed, or null if unusable. */
export function deserializeSeed(raw: unknown): Seed | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as Record<string, unknown>;
  if (!str(r.id) || !str(r.title) || !r.title.trim()) return null;

  const categories = strArray(r.categories).filter((c) =>
    (CATEGORIES as string[]).includes(c)
  ) as SeedCategory[];
  const preferredTimes = strArray(r.preferredTimes).filter((t) =>
    (TIMES as string[]).includes(t)
  ) as SemanticTime[];

  const dur = Number(r.estimatedDurationMin);

  return {
    id: r.id,
    rawText: str(r.rawText) ? r.rawText : r.title,
    title: r.title,
    description: str(r.description) ? r.description : undefined,
    categories: categories.length ? categories : ["recovery"],
    minimumAction: str(r.minimumAction) && r.minimumAction.trim() ? r.minimumAction : "做一点也算",
    estimatedDurationMin: Number.isFinite(dur) && dur > 0 ? dur : 10,
    energyRequired: oneOf(r.energyRequired, ENERGIES, "low"),
    locationType: oneOf(r.locationType, LOCATIONS, "anywhere"),
    preferredTimes,
    triggerConditions: strArray(r.triggerConditions),
    status: oneOf(r.status, STATUSES, "active"),
    createdAt: str(r.createdAt) ? r.createdAt : new Date().toISOString(),
    updatedAt: str(r.updatedAt) ? r.updatedAt : new Date().toISOString(),
  };
}

/** Validate + coerce an unknown record into a DailyTrace, or null if unusable. */
export function deserializeTrace(raw: unknown): DailyTrace | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as Record<string, unknown>;
  if (!str(r.id) || !str(r.text) || !r.text.trim()) return null;
  if (!str(r.date)) return null;

  const category =
    str(r.category) && (CATEGORIES as string[]).includes(r.category)
      ? (r.category as SeedCategory)
      : undefined;

  return {
    id: r.id,
    date: r.date,
    seedId: str(r.seedId) ? r.seedId : undefined,
    opportunityId: str(r.opportunityId) ? r.opportunityId : undefined,
    text: r.text,
    category,
    partial: r.partial === true,
    createdAt: str(r.createdAt) ? r.createdAt : new Date().toISOString(),
  };
}

export function deserializeSeeds(raw: unknown): Seed[] {
  if (!Array.isArray(raw)) return [];
  return raw.map(deserializeSeed).filter((s): s is Seed => s !== null);
}

export function deserializeTraces(raw: unknown): DailyTrace[] {
  if (!Array.isArray(raw)) return [];
  return raw.map(deserializeTrace).filter((t): t is DailyTrace => t !== null);
}
