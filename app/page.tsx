import { copy } from "@/lib/copy";
import LateNightThemeOffer from "@/components/design/LateNightThemeOffer";
import IntroCard from "@/components/IntroCard";
import AmbientOrbit from "@/components/home/AmbientOrbit";

export default function HomePage() {
  return (
    <div className="flex min-h-[78dvh] flex-col items-center justify-center gap-7">
      <p className="text-[13px] tracking-[0.3em] text-[var(--text-muted)]">{copy.appTitle}</p>

      <IntroCard />
      <LateNightThemeOffer />

      <AmbientOrbit />
    </div>
  );
}
