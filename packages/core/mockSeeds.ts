import type { Seed, SeedCategory, Energy, LocationType, SemanticTime } from "@core/types";
import { uid, nowIso } from "@core/utils";

export type SeedTemplate = {
  title: string;
  rawText: string;
  description?: string;
  categories: SeedCategory[];
  minimumAction: string;
  estimatedDurationMin: number;
  energyRequired: Energy;
  locationType: LocationType;
  preferredTimes: SemanticTime[];
  triggerConditions: string[];
};

export const mockSeeds: SeedTemplate[] = [
  {
    title: "记 3 个法语单词",
    rawText: "我想记几个法语单词",
    categories: ["learning"],
    minimumAction: "记住 3 个法语词，不要求复习更多",
    estimatedDurationMin: 5,
    energyRequired: "low",
    locationType: "anywhere",
    preferredTimes: ["lunch", "evening", "transit"],
    triggerConditions: ["short_free_time", "low_energy_ok"],
  },
  {
    title: "坐一会野外",
    rawText: "我想找个天气好的时候坐一会野外",
    categories: ["recovery", "exploration"],
    minimumAction: "在户外坐 10 分钟，不刷手机",
    estimatedDurationMin: 15,
    energyRequired: "low",
    locationType: "outdoor",
    preferredTimes: ["afternoon", "after_work", "weekend"],
    triggerConditions: ["weather_good", "near_outdoor", "free_time_15min"],
  },
  {
    title: "去市中心走走",
    rawText: "我想去市中心走走，喝杯咖啡，拍点照片",
    categories: ["exploration", "aesthetic"],
    minimumAction: "到一个街区走 20 分钟，拍一张照片",
    estimatedDurationMin: 90,
    energyRequired: "medium",
    locationType: "downtown",
    preferredTimes: ["weekend", "after_work"],
    triggerConditions: ["free_time_90min", "energy_medium", "not_late_night"],
  },
  {
    title: "吃一顿热饭",
    rawText: "我想别再糊弄吃饭，给自己吃一顿热的",
    categories: ["body"],
    minimumAction: "吃一顿有蛋白质的热饭",
    estimatedDurationMin: 20,
    energyRequired: "low",
    locationType: "home",
    preferredTimes: ["evening"],
    triggerConditions: ["evening", "low_energy_ok"],
  },
  {
    title: "亲手理解一个模块",
    rawText: "我不想全交给 Claude，我想亲手理解一个芯片模块",
    categories: ["creation", "learning"],
    minimumAction: "看懂 20 行代码，写 5 行笔记",
    estimatedDurationMin: 30,
    energyRequired: "medium",
    locationType: "computer",
    preferredTimes: ["evening", "weekend"],
    triggerConditions: ["at_computer", "energy_medium", "not_late_night"],
  },
  {
    title: "夺回一点方向盘",
    rawText: "我不想全交给 Claude 做，自己没有长进",
    categories: ["creation", "learning"],
    minimumAction: "打开 Claude 写的代码，标出 10 行我真的懂的地方",
    estimatedDurationMin: 20,
    energyRequired: "medium",
    locationType: "computer",
    preferredTimes: ["evening", "weekend"],
    triggerConditions: ["at_computer", "avoidant_mood"],
  },
  {
    title: "给一个人发一句真话",
    rawText: "我想被爱，也想爱别人",
    categories: ["connection"],
    minimumAction: "给一个不会消耗你的人发一句真诚的话",
    estimatedDurationMin: 5,
    energyRequired: "low",
    locationType: "anywhere",
    preferredTimes: ["evening", "weekend"],
    triggerConditions: ["lonely", "want_love", "short_free_time"],
  },
  {
    title: "深夜止损",
    rawText: "现在已经很晚了，我不想再让今天消失",
    categories: ["body", "recovery"],
    minimumAction: "喝水、洗漱、关机、上床，完成一个就算",
    estimatedDurationMin: 8,
    energyRequired: "low",
    locationType: "home",
    preferredTimes: ["late_night"],
    triggerConditions: ["late_night", "rescue_mode"],
  },
];

/** Turn a template into a full Seed with id + timestamps. */
export function materializeSeed(t: SeedTemplate): Seed {
  const ts = nowIso();
  return {
    id: uid("seed"),
    rawText: t.rawText,
    title: t.title,
    description: t.description,
    categories: t.categories,
    minimumAction: t.minimumAction,
    estimatedDurationMin: t.estimatedDurationMin,
    energyRequired: t.energyRequired,
    locationType: t.locationType,
    preferredTimes: t.preferredTimes,
    triggerConditions: t.triggerConditions,
    status: "active",
    createdAt: ts,
    updatedAt: ts,
  };
}

export function seedMockGarden(): Seed[] {
  return mockSeeds.map(materializeSeed);
}
