import type { CSSProperties } from "react";
import GlassFilters from "../shared/GlassFilters";
import SceneBackground from "../shared/SceneBackground";
import BubbleField from "../shared/BubbleField";

// faint rising bubble streams (x%, delay s, duration s)
const streams = [
  [14, 0, 9],
  [28, 3.5, 11],
  [46, 1.5, 8],
  [62, 5, 10],
  [78, 2.5, 12],
  [88, 6.5, 9],
] as const;

/** Ocean skin — the field with buoyancy (wishes float up toward the surface, the
 * bottom edge is the ocean floor), under a caustic water surface, slow light
 * shafts, and faint rising bubble streams. */
export default function OceanField() {
  return (
    <>
      <GlassFilters />
      <SceneBackground />
      <div className="ocean-ambience" aria-hidden>
        <span className="ocean-surface" />
        <span className="ocean-shaft" style={{ left: "18%" }} />
        <span className="ocean-shaft" style={{ left: "52%", animationDelay: "4s" }} />
        <span className="ocean-shaft" style={{ left: "80%", animationDelay: "8s" }} />
        {streams.map(([x, delay, dur], i) => (
          <span
            key={i}
            className="ocean-stream"
            style={{
              left: `${x}%`,
              ["--st-delay"]: `${delay}s`,
              ["--st-dur"]: `${dur}s`,
            } as CSSProperties}
          />
        ))}
      </div>
      <div className="relative z-10 w-full">
        <BubbleField buoyancy />
      </div>
    </>
  );
}
