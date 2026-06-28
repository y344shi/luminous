import GlassFilters from "../shared/GlassFilters";
import SceneBackground from "../shared/SceneBackground";
import BubbleField from "../shared/BubbleField";

/** Ocean skin — the same field with buoyancy: wishes float up toward the surface
 * (the bottom edge is the ocean floor), most relevant highest. */
export default function OceanField() {
  return (
    <>
      <GlassFilters />
      <SceneBackground />
      <div className="relative z-10 w-full">
        <BubbleField buoyancy />
      </div>
    </>
  );
}
