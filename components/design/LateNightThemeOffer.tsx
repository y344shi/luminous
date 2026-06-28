"use client";

import { useEffect, useState } from "react";
import { useStore } from "@/lib/store";
import { storage } from "@/lib/storage";
import { copy } from "@core/copy";
import { localDateKey } from "@core/utils";
import { isLateNightHour } from "@core/semanticTime";
import BreathingCard from "@/components/design/BreathingCard";
import SoftButton from "@/components/design/SoftButton";

/**
 * At late night, gently OFFER the soft_ritual theme. Never forces it:
 * one tap accepts, one tap dismisses for the rest of tonight.
 */
export default function LateNightThemeOffer() {
  const hydrated = useStore((s) => s.hydrated);
  const theme = useStore((s) => s.settings.theme);
  const setTheme = useStore((s) => s.setTheme);

  // Compute time on the client only, to avoid SSR/client mismatch.
  const [show, setShow] = useState(false);

  useEffect(() => {
    if (!hydrated) return;
    const lateNow = isLateNightHour(new Date().getHours());
    const dismissed = storage.loadRitualOfferDismissed() === localDateKey();
    setShow(lateNow && theme !== "soft_ritual" && !dismissed);
  }, [hydrated, theme]);

  if (!show) return null;

  function accept() {
    setTheme("soft_ritual");
    setShow(false);
  }
  function dismiss() {
    storage.saveRitualOfferDismissed(localDateKey());
    setShow(false);
  }

  return (
    <BreathingCard soft rise className="flex flex-col gap-3">
      <p className="text-[14px] leading-relaxed text-[var(--text-secondary)]">
        {copy.lateNight.themeOffer}
      </p>
      <div className="flex gap-2">
        <SoftButton variant="soft" full onClick={accept}>
          {copy.lateNight.themeAccept}
        </SoftButton>
        <SoftButton variant="ghost" full onClick={dismiss}>
          {copy.lateNight.themeDismiss}
        </SoftButton>
      </div>
    </BreathingCard>
  );
}
