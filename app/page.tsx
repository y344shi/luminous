import { copy } from "@/lib/copy";
import LateNightThemeOffer from "@/components/design/LateNightThemeOffer";
import IntroCard from "@/components/IntroCard";
import BubbleField from "@/components/home/BubbleField";
import SceneBackground from "@/components/home/SceneBackground";

export default function HomePage() {
  return (
    <div className="relative flex min-h-[82dvh] flex-col items-center overflow-hidden">
      <SceneBackground />

      <p className="serif relative z-30 pt-1 text-[13px] tracking-[0.42em] text-[var(--text-muted)]">
        {copy.appTitle}
      </p>

      <div className="relative z-30 w-full">
        <IntroCard />
        <LateNightThemeOffer />
      </div>

      <div className="relative z-10 w-full">
        <BubbleField />
      </div>
    </div>
  );
}
