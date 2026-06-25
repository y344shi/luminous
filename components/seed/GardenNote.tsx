"use client";

import { useStore } from "@/lib/store";
import { copy } from "@/lib/copy";
import BreathingCard from "@/components/design/BreathingCard";

/**
 * On first run the garden is pre-seeded with sample wishes so it never feels
 * dead. This gentle, dismissible note makes clear they're examples — not
 * someone else's data — and disappears once the user adds their own or taps it.
 */
export default function GardenNote() {
  const hydrated = useStore((s) => s.hydrated);
  const samplesPlanted = useStore((s) => s.samplesPlanted);
  const dismiss = useStore((s) => s.dismissSamplesNote);

  if (!hydrated || !samplesPlanted) return null;

  return (
    <BreathingCard soft rise className="flex flex-col gap-3">
      <p className="whitespace-pre-line text-[14px] leading-relaxed text-[var(--text-secondary)]">
        {copy.garden.sampleNote}
      </p>
      <button
        onClick={dismiss}
        className="self-start rounded-full bg-[var(--surface)] px-4 py-2 text-[13px] text-[var(--text-secondary)] transition-colors hover:bg-[var(--surface-soft)]"
      >
        {copy.garden.sampleNoteDismiss}
      </button>
    </BreathingCard>
  );
}
