import type { Seed } from "@core/types";
import { categoryMeta, energyLabel, durationLabel } from "@/lib/categoryMeta";
import BreathingCard from "@/components/design/BreathingCard";
import { IllustrationArt } from "@/components/home/shared/illustrationPacks";
import { illustrationCategory } from "@/lib/illustration";

const statusLabel: Record<Seed["status"], string> = {
  active: "在等一个时机",
  sleeping: "先睡着",
  completed: "曾经做到过",
  archived: "收起来了",
};

export default function SeedCard({ seed, illustrationStyle }: { seed: Seed; illustrationStyle: string }) {
  const cat = illustrationCategory(seed.categories, seed.id);
  return (
    <BreathingCard className="flex flex-col gap-3">
      <div className="flex items-start justify-between gap-3">
        <div className="flex items-center gap-2.5">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-[#f1ece2]">
            <IllustrationArt style={illustrationStyle} category={cat} className="h-full w-full" />
          </span>
          <h3 className="text-[16px] font-medium text-[var(--text)]">{seed.title}</h3>
        </div>
        <span className="shrink-0 rounded-full bg-[var(--surface-soft)] px-2.5 py-1 text-[11px] text-[var(--text-muted)]">
          {statusLabel[seed.status]}
        </span>
      </div>

      <p className="text-[14px] leading-relaxed text-[var(--text-secondary)]">
        {seed.minimumAction}
      </p>

      <div className="flex flex-wrap gap-2 pt-1">
        {seed.categories.map((c) => (
          <span
            key={c}
            className="rounded-full bg-[var(--accent-soft)] px-2.5 py-1 text-[11px] text-[var(--text-secondary)]"
          >
            {categoryMeta[c]?.label}
          </span>
        ))}
        <span className="rounded-full bg-[var(--surface-soft)] px-2.5 py-1 text-[11px] text-[var(--text-muted)]">
          {durationLabel(seed.estimatedDurationMin)}
        </span>
        <span className="rounded-full bg-[var(--surface-soft)] px-2.5 py-1 text-[11px] text-[var(--text-muted)]">
          {energyLabel[seed.energyRequired]}
        </span>
      </div>
    </BreathingCard>
  );
}
