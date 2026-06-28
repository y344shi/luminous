import type { Opportunity, Seed } from "@core/types";
import { energyLabel } from "@core/categoryMeta";
import { copy } from "@core/copy";
import BreathingCard from "@/components/design/BreathingCard";
import SoftButton from "@/components/design/SoftButton";
import { IllustrationArt } from "@/components/home/shared/illustrationPacks";
import { illustrationCategory } from "@core/illustration";

export default function OpportunityCard({
  opportunity,
  seed,
  onStart,
  onSwap,
  onLater,
  canSwap,
  illustrationStyle,
}: {
  opportunity: Opportunity;
  seed: Seed;
  onStart: () => void;
  onSwap: () => void;
  onLater: () => void;
  canSwap: boolean;
  illustrationStyle: string;
}) {
  const cat = illustrationCategory(seed.categories, seed.id);
  return (
    <BreathingCard rise className="flex flex-col gap-4">
      <p className="text-[12px] tracking-wide text-[var(--text-muted)]">
        {energyLabel[seed.energyRequired]}的一个契机
      </p>

      <div className="flex items-center gap-2.5">
        <span className="flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-xl bg-[#f1ece2]">
          <IllustrationArt style={illustrationStyle} category={cat} className="h-full w-full" />
        </span>
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
