import {
  Monitor, Trees, Coffee, Milestone, Moon, Sofa, Briefcase, Sparkles,
  BookOpen, Heart, Footprints, Soup, PenLine, Leaf, Wind,
  type LucideIcon,
} from "lucide-react";
import type { SeedCategory } from "@core/types";
import type { SceneKey } from "@core/ambient";

/**
 * Transparent line-art glyphs (Lucide, MIT) — a refined, cohesive icon language
 * to replace system emoji. Thin strokes that read like delicate ink on glass.
 */

const sceneIcon: Record<SceneKey, LucideIcon> = {
  desk: Monitor,
  grass: Trees,
  highway: Milestone,
  cafe: Coffee,
  night: Moon,
  home: Sofa,
  work: Briefcase,
  spark: Sparkles,
};

const categoryIcon: Record<SeedCategory, LucideIcon> = {
  body: Soup,
  creation: PenLine,
  connection: Heart,
  exploration: Footprints,
  recovery: Wind,
  learning: BookOpen,
  aesthetic: Leaf,
};

export function SceneGlyph({ icon, size = 36 }: { icon: SceneKey; size?: number }) {
  const Icon = sceneIcon[icon];
  return <Icon size={size} strokeWidth={1.3} className="text-[var(--accent-text)]" aria-hidden />;
}

export function CategoryGlyph({
  category,
  size = 22,
  className,
}: {
  category: SeedCategory;
  size?: number;
  className?: string;
}) {
  const Icon = categoryIcon[category] ?? Sparkles;
  return <Icon size={size} strokeWidth={1.5} className={className ?? "text-[var(--accent-text)]"} aria-hidden />;
}
