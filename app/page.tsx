import LateNightThemeOffer from "@/components/design/LateNightThemeOffer";
import IntroCard from "@/components/IntroCard";
import PaperHome from "@/components/home/PaperHome";

export default async function HomePage({
  searchParams,
}: {
  searchParams: Promise<{ shot?: string }>;
}) {
  // ?shot=1 → a clean capture (no first-run overlays) for the per-branch gallery.
  const { shot } = await searchParams;
  const clean = shot === "1";

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
