import { copy } from "@/lib/copy";
import { AESTHETIC } from "@/lib/aesthetic";
import LateNightThemeOffer from "@/components/design/LateNightThemeOffer";
import IntroCard from "@/components/IntroCard";
import GlassField from "@/components/home/skins/GlassField";
import OceanField from "@/components/home/skins/OceanField";
import PaperHome from "@/components/home/skins/PaperHome";

export default async function HomePage({
  searchParams,
}: {
  searchParams: Promise<{ shot?: string }>;
}) {
  // ?shot=1 → a clean capture (no first-run overlays) for the per-skin gallery.
  const { shot } = await searchParams;
  const clean = shot === "1";

  // Paper has its own warm-sheet layout; glass + ocean share the bubble chrome.
  if (AESTHETIC === "paper") {
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

  const Skin = AESTHETIC === "ocean" ? OceanField : GlassField;
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
