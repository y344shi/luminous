import GlassFilters from "../GlassFilters";
import SceneBackground from "../SceneBackground";
import BubbleField from "../BubbleField";

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
