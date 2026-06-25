import type {
  SeedCategory,
  Energy,
  LocationType,
  SemanticTime,
} from "./types";
import type { SeedDraft } from "./seedParser";

/**
 * System prompt for the real-AI seed parser. Encodes the SeedDraft schema AND
 * the product's tone rules so a model can't turn a soft wish into homework.
 * Only the user's short wish text is ever sent alongside this.
 */
export const SEED_PARSER_SYSTEM_PROMPT = `你在帮助一个叫《今天别消失》的生活锚点 app。
用户会给你一句很软、很生活化的小愿望。请把它整理成一颗"种子"（Seed），用 JSON 返回。

严格要求：
- 只返回一个 JSON 对象，不要任何解释、前后缀或代码块标记。
- 语气温柔，不要像任务、不要像作业、不要制造压力或愧疚。
- minimumAction 必须非常小，小到现在就能开始；允许"做一点也算"。
- 不要 deadline、不要打卡、不要高要求。

JSON 字段：
{
  "title": "不超过 16 字的短标题",
  "description": "一句温柔的描述（可选）",
  "categories": ["body|creation|connection|exploration|recovery|learning|aesthetic 中的一到两个"],
  "minimumAction": "最低完成动作，很小",
  "estimatedDurationMin": 数字（分钟）,
  "energyRequired": "low|medium|high",
  "locationType": "anywhere|home|work|outdoor|downtown|computer|transit|unknown",
  "preferredTimes": ["morning|lunch|afternoon|after_work|evening|late_night|weekend|transit 中的若干"],
  "triggerConditions": ["简短的英文条件标签，如 short_free_time / weather_good"]
}`;

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

const str = (v: unknown): v is string => typeof v === "string";
function strArray(v: unknown): string[] {
  return Array.isArray(v) ? v.filter(str) : [];
}
function oneOf<T extends string>(v: unknown, allowed: T[], fallback: T): T {
  return str(v) && (allowed as string[]).includes(v) ? (v as T) : fallback;
}

/**
 * Validate + coerce a model's JSON into a SeedDraft, or null if unusable.
 * The same safety net as the local parser: bad enums → safe defaults, a
 * missing title/minimumAction → reject (caller then falls back to the mock).
 */
export function parseModelDraft(raw: unknown, rawText: string): SeedDraft | null {
  let obj = raw;
  if (str(raw)) {
    // Models sometimes wrap JSON in prose/code fences — extract the first object.
    const match = raw.match(/\{[\s\S]*\}/);
    if (!match) return null;
    try {
      obj = JSON.parse(match[0]);
    } catch {
      return null;
    }
  }
  if (!obj || typeof obj !== "object") return null;
  const r = obj as Record<string, unknown>;
  if (!str(r.title) || !r.title.trim()) return null;
  if (!str(r.minimumAction) || !r.minimumAction.trim()) return null;

  const categories = strArray(r.categories).filter((c) =>
    (CATEGORIES as string[]).includes(c)
  ) as SeedCategory[];
  const preferredTimes = strArray(r.preferredTimes).filter((t) =>
    (TIMES as string[]).includes(t)
  ) as SemanticTime[];
  const dur = Number(r.estimatedDurationMin);

  return {
    title: r.title.trim().slice(0, 16),
    rawText,
    description: str(r.description) ? r.description : undefined,
    categories: categories.length ? categories : ["recovery"],
    minimumAction: r.minimumAction.trim(),
    estimatedDurationMin: Number.isFinite(dur) && dur > 0 ? dur : 10,
    energyRequired: oneOf(r.energyRequired, ENERGIES, "low"),
    locationType: oneOf(r.locationType, LOCATIONS, "anywhere"),
    preferredTimes: preferredTimes.length ? preferredTimes : ["evening"],
    triggerConditions: strArray(r.triggerConditions),
  };
}
