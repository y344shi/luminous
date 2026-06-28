import GlassFilters from "../GlassFilters";
import SceneBackground from "../SceneBackground";
import BubbleField from "../BubbleField";

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
