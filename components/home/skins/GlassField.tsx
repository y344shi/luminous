import GlassFilters from "../shared/GlassFilters";
import SceneBackground from "../shared/SceneBackground";
import BubbleField from "../shared/BubbleField";

/** Glass skin — the liquid-glass bubble field over the sensed scene. */
export default function GlassField() {
  return (
    <>
      <GlassFilters />
      <SceneBackground />
      <div className="relative z-10 w-full">
        <BubbleField />
      </div>
    </>
  );
}
