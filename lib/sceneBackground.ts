import type { SceneKey } from "./ambient";

/**
 * Warm "wallpaper" for each sensed scene — the background reflects where you
 * seem to be. These hand-tuned gradients are the always-works base; a curated
 * high-res / 3D image can drop into `image` later (see docs/scene-library.md)
 * and render over the gradient, under a theme scrim, for legibility. Pure.
 */
export type SceneVisual = { gradient: string; image?: string };

const VISUALS: Record<SceneKey, SceneVisual> = {
  desk: {
    gradient:
      "radial-gradient(120% 90% at 72% 18%, rgba(246,206,138,0.45), transparent 58%), linear-gradient(160deg, #f7efe0, #ece0cd)",
  },
  home: {
    gradient:
      "radial-gradient(110% 85% at 30% 22%, rgba(238,190,170,0.42), transparent 60%), linear-gradient(160deg, #f6ece6, #eedfd6)",
  },
  night: {
    gradient:
      "radial-gradient(70% 55% at 76% 16%, rgba(206,214,255,0.42), transparent 60%), linear-gradient(170deg, #2c2945, #1a1828)",
  },
  grass: {
    gradient:
      "radial-gradient(120% 80% at 50% 8%, rgba(255,233,168,0.45), transparent 55%), linear-gradient(165deg, #e8f1d6, #cee2bd)",
  },
  highway: {
    gradient:
      "radial-gradient(90% 60% at 50% 6%, rgba(255,224,196,0.4), transparent 55%), linear-gradient(180deg, #dcccea, #b6a4d4 48%, #6a6290)",
  },
  cafe: {
    gradient:
      "radial-gradient(110% 85% at 30% 24%, rgba(232,199,154,0.45), transparent 60%), linear-gradient(160deg, #eddcc6, #d7c0a4)",
  },
  work: {
    gradient:
      "radial-gradient(110% 80% at 70% 18%, rgba(214,224,238,0.5), transparent 60%), linear-gradient(165deg, #e9eef4, #d4dbe7)",
  },
  spark: {
    gradient:
      "radial-gradient(110% 80% at 50% 18%, rgba(255,233,200,0.4), transparent 60%), linear-gradient(160deg, #f4efe7, #eae2d6)",
  },
};

export function sceneVisual(icon: SceneKey): SceneVisual {
  return VISUALS[icon] ?? VISUALS.spark;
}
