import type { Opportunity, Seed } from "@/lib/types";
import { categoryMeta, energyLabel } from "@/lib/categoryMeta";
import { copy } from "@/lib/copy";
import BreathingCard from "@/components/design/BreathingCard";
import SoftButton from "@/components/design/SoftButton";

export default function OpportunityCard({
  opportunity,
  seed,
  onStart,
  onSwap,
  onLater,
  canSwap,
}: {
  opportunity: Opportunity;
  seed: Seed;
  onStart: () => void;
  onSwap: () => void;
  onLater: () => void;
  canSwap: boolean;
}) {
  const cat = seed.categories[0];
  return (
    <BreathingCard rise className="flex flex-col gap-4">
      <p className="text-[12px] tracking-wide text-[var(--text-muted)]">
        {energyLabel[seed.energyRequired]}的一个契机
      </p>

      <div className="flex items-center gap-2">
        <span className="text-xl">{categoryMeta[cat]?.emoji}</span>
        <h2 className="text-[19px] font-medium text-[var(--text)]">{seed.title}</h2>
      </div>

      <div>
        <p className="text-[12px] text-[var(--text-muted)]">{copy.now.minLabel}</p>
        <p className="mt-1 text-[15px] text-[var(--text)]">{opportunity.suggestedAction}</p>
      </div>

      <div className="rounded-2xl bg-[var(--surface-soft)] p-4">
        <p className="text-[12px] text-[var(--text-muted)]">{copy.now.reasonLabel}</p>
        <p className="mt-1 text-[14px] leading-relaxed text-[var(--text-secondary)]">
          {opportunity.reason}
        </p>
      </div>

      <div className="flex flex-col gap-2 pt-1">
        <SoftButton full onClick={onStart}>
          {copy.now.start}
        </SoftButton>
        <div className="flex gap-2">
          {canSwap && (
            <SoftButton variant="soft" full onClick={onSwap}>
              {copy.now.swap}
            </SoftButton>
          )}
          <SoftButton variant="ghost" full onClick={onLater}>
            {copy.now.later}
          </SoftButton>
        </div>
      </div>
    </BreathingCard>
  );
}
