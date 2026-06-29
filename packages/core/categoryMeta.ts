import type { SeedCategory, Energy } from "@core/types";

export const categoryMeta: Record<SeedCategory, { label: string; emoji: string }> = {
  body: { label: "身体", emoji: "🍵" },
  creation: { label: "创造", emoji: "✏️" },
  connection: { label: "连接", emoji: "🤍" },
  exploration: { label: "探索", emoji: "🚶" },
  recovery: { label: "恢复", emoji: "🫧" },
  learning: { label: "学习", emoji: "📓" },
  aesthetic: { label: "审美", emoji: "🌿" },
};

export const energyLabel: Record<Energy, string> = {
  low: "低能量",
  medium: "中等",
  high: "需要点劲",
};

export function durationLabel(min: number): string {
  if (min <= 5) return "几分钟";
  if (min <= 15) return "十几分钟";
  if (min <= 30) return "半小时内";
  if (min <= 60) return "一小时内";
  return "可长可短";
}
