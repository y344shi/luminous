"use client";

import { useStore } from "@/lib/store";
import { AESTHETIC } from "@/lib/aesthetic";
import { copy } from "@/lib/copy";
import LateNightThemeOffer from "@/components/design/LateNightThemeOffer";
import IntroCard from "@/components/IntroCard";
import GlassField from "./skins/GlassField";
import OceanField from "./skins/OceanField";
import PaperHome from "./skins/PaperHome";

/**
 * Renders the active Home skin. The look is chosen at **runtime** from the user's
 * setting (Settings → 外观风格), falling back to the build-time `NEXT_PUBLIC_AESTHETIC`
 * before the store hydrates so there's no flash. Switching is instant, no rebuild.
 */
export default function HomeSkin({ clean }: { clean: boolean }) {
  const hydrated = useStore((s) => s.hydrated);
  const setting = useStore((s) => s.settings.aesthetic);
  const a = hydrated ? setting : AESTHETIC;

  if (a === "paper") {
    return (
      <div className="relative w-full">
        {!clean && (
          <div className="relative z-30 w-full px-5 pt-3">
            <IntroCard />
            <LateNightThemeOffer />
          </div>
        )}
        <PaperHome />
      </div>
    );
  }

  const Skin = a === "ocean" ? OceanField : GlassField;
  return (
    <div className="relative flex min-h-[82dvh] flex-col items-center overflow-hidden">
      <p className="serif relative z-30 pt-1 text-[13px] tracking-[0.42em] text-[var(--text-muted)]">
        {copy.appTitle}
      </p>
      {!clean && (
        <div className="relative z-30 w-full">
          <IntroCard />
          <LateNightThemeOffer />
        </div>
      )}
      <Skin />
    </div>
  );
}
