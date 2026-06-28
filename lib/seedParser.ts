import type {
  Seed,
  SeedCategory,
  Energy,
  LocationType,
  SemanticTime,
} from "@core/types";
import { uid, nowIso } from "@core/utils";
import { mockSeeds, type SeedTemplate } from "./mockSeeds";

export type SeedDraft = SeedTemplate;

type Rule = {
  match: RegExp;
  categories: SeedCategory[];
  location?: LocationType;
  energy?: Energy;
  durationMin?: number;
  times?: SemanticTime[];
  triggers?: string[];
  minimumAction?: string;
  title?: string;
};

// Keyword heuristics. Order matters: earlier, more specific rules win their fields.
const rules: Rule[] = [
  {
    match: /法语|单词|外语|背词|french|word/i,
    categories: ["learning"],
    location: "anywhere",
    energy: "low",
    durationMin: 5,
    times: ["lunch", "evening", "transit"],
    triggers: ["short_free_time", "low_energy_ok"],
    minimumAction: "记住 3 个词，不要求复习更多",
    title: "记几个词",
  },
  {
    match: /野外|草地|公园|户外|自然|河边|绿地/,
    categories: ["recovery", "exploration"],
    location: "outdoor",
    energy: "low",
    durationMin: 15,
    times: ["afternoon", "after_work", "weekend"],
    triggers: ["weather_good", "near_outdoor", "free_time_15min"],
    minimumAction: "在户外坐 10 分钟，不刷手机",
    title: "坐一会野外",
  },
  {
    match: /市中心|街区|逛|downtown|城市|街上|散步去/,
    categories: ["exploration", "aesthetic"],
    location: "downtown",
    energy: "medium",
    durationMin: 90,
    times: ["weekend", "after_work"],
    triggers: ["free_time_90min", "energy_medium", "not_late_night"],
    minimumAction: "到一个街区走 20 分钟，拍一张照片",
    title: "去走走",
  },
  {
    match: /热饭|吃饭|做饭|做菜|煮|吃一顿|蛋白质|好好吃/,
    categories: ["body"],
    location: "home",
    energy: "low",
    durationMin: 20,
    times: ["evening"],
    triggers: ["evening", "low_energy_ok"],
    minimumAction: "给自己吃一顿有蛋白质的热饭",
    title: "吃一顿热饭",
  },
  {
    match: /claude|代码|模块|芯片|testbench|bug|理解.*代码|看懂/i,
    categories: ["creation", "learning"],
    location: "computer",
    energy: "medium",
    durationMin: 25,
    times: ["evening", "weekend"],
    triggers: ["at_computer", "not_late_night"],
    minimumAction: "看懂 20 行代码，写 5 行笔记",
    title: "亲手理解一点代码",
  },
  {
    match: /朋友|发消息|联系|表达|感谢|温柔|被爱|爱别人|消息|回信/,
    categories: ["connection"],
    location: "anywhere",
    energy: "low",
    durationMin: 5,
    times: ["evening", "weekend"],
    triggers: ["short_free_time"],
    minimumAction: "给一个不会消耗你的人发一句真诚的话",
    title: "发一句真话",
  },
  {
    match: /拍照|拍一张|光|颜色|树|美|风景|photo|记录一个/,
    categories: ["aesthetic"],
    location: "anywhere",
    energy: "low",
    durationMin: 5,
    times: ["afternoon", "after_work", "weekend"],
    triggers: ["short_free_time"],
    minimumAction: "拍一张让你停下来的光或颜色",
    title: "留住一个画面",
  },
  {
    match: /睡|洗漱|关机|止损|喝水|休息|太晚|别熬/,
    categories: ["body", "recovery"],
    location: "home",
    energy: "low",
    durationMin: 8,
    times: ["late_night", "evening"],
    triggers: ["late_night", "rescue_mode"],
    minimumAction: "喝水、洗漱、关机、上床，完成一个就算",
    title: "今天先这样",
  },
];

function titleFromText(raw: string): string {
  const cleaned = raw.replace(/^我?\s*(想|要|希望|得|该)\s*/u, "").trim();
  const head = cleaned.split(/[，。,.\n]/)[0] ?? cleaned;
  return (head || cleaned || "一个小愿望").slice(0, 16);
}

/**
 * Mock parser: turn a soft sentence into a small, low-friction Seed draft.
 * Principles: keep the minimum action tiny; never sound like homework.
 */
export function parseSeedMock(raw: string): SeedDraft {
  const text = raw.trim();

  // First try matching one of our known wish shapes for the best minimum action.
  let categories: SeedCategory[] = [];
  let location: LocationType = "anywhere";
  let energy: Energy = "low";
  let durationMin = 10;
  let times: SemanticTime[] = ["evening"];
  let triggers: string[] = ["short_free_time"];
  let minimumAction = "";
  let title = "";

  for (const rule of rules) {
    if (rule.match.test(text)) {
      categories = Array.from(new Set([...categories, ...rule.categories]));
      if (rule.location) location = rule.location;
      if (rule.energy) energy = rule.energy;
      if (rule.durationMin) durationMin = rule.durationMin;
      if (rule.times) times = rule.times;
      if (rule.triggers) triggers = rule.triggers;
      if (rule.minimumAction && !minimumAction) minimumAction = rule.minimumAction;
      if (rule.title && !title) title = rule.title;
    }
  }

  if (categories.length === 0) {
    categories = ["recovery"];
    minimumAction = minimumAction || "做最小的一步，做到一点也算";
  }

  return {
    title: title || titleFromText(text),
    rawText: text,
    description: text.length > 0 ? text : undefined,
    categories,
    minimumAction: minimumAction || "做最小的一步，做到一点也算",
    estimatedDurationMin: durationMin,
    energyRequired: energy,
    locationType: location,
    preferredTimes: times,
    triggerConditions: triggers,
  };
}

/** Promote a draft into a full persisted Seed. */
export function draftToSeed(draft: SeedDraft): Seed {
  const ts = nowIso();
  return {
    id: uid("seed"),
    rawText: draft.rawText,
    title: draft.title,
    description: draft.description,
    categories: draft.categories,
    minimumAction: draft.minimumAction,
    estimatedDurationMin: draft.estimatedDurationMin,
    energyRequired: draft.energyRequired,
    locationType: draft.locationType,
    preferredTimes: draft.preferredTimes,
    triggerConditions: draft.triggerConditions,
    status: "active",
    createdAt: ts,
    updatedAt: ts,
  };
}

// Re-export so a future real-AI parser can swap in behind the same shape.
export type { SeedTemplate };
export { mockSeeds };
