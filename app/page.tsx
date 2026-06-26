import { copy } from "@/lib/copy";
import LateNightThemeOffer from "@/components/design/LateNightThemeOffer";
import IntroCard from "@/components/IntroCard";
import AmbientOrbit from "@/components/home/AmbientOrbit";

export default function HomePage() {
  return (
    <div className="relative flex min-h-[80dvh] flex-col items-center justify-center gap-8 overflow-hidden">
      <div className="home-aurora" aria-hidden />

      <p className="serif relative z-10 text-[13px] tracking-[0.42em] text-[var(--text-muted)]">
        {copy.appTitle}
      </p>

      <div className="relative z-10 flex w-full flex-col items-center gap-8">
        <IntroCard />
        <LateNightThemeOffer />
        <AmbientOrbit />
      </div>
    </div>
  );
}
