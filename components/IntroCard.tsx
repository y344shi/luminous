"use client";

import { useStore } from "@/lib/store";
import { copy } from "@/lib/copy";
import BreathingCard from "@/components/design/BreathingCard";
import SoftButton from "@/components/design/SoftButton";

/**
 * A calm, one-time, dismissible introduction shown on Home for new users —
 * frames Seed / Trace / "别消失" so the pre-seeded garden isn't a mystery.
 * Disappears for good once dismissed (persisted), like the garden note.
 */
export default function IntroCard() {
  const hydrated = useStore((s) => s.hydrated);
  const introSeen = useStore((s) => s.introSeen);
  const dismiss = useStore((s) => s.dismissIntro);

  if (!hydrated || introSeen) return null;

  return (
    <BreathingCard rise className="flex flex-col gap-4">
      <p className="whitespace-pre-line text-[15px] leading-relaxed text-[var(--text)]">
        {copy.intro.body}
      </p>
      <SoftButton onClick={dismiss} className="self-start">
        {copy.intro.cta}
      </SoftButton>
    </BreathingCard>
  );
}
