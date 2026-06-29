import type { SceneKey } from "@core/ambient";

/**
 * Wallpaper for each sensed scene — the background reflects where you seem to be.
 * Layered "mesh" gradients are the always-works, wallpaper-grade base. A curated
 * high-res photo can layer over the gradient (under a theme scrim) when an image
 * URL is configured — via `NEXT_PUBLIC_SCENE_IMAGES` (a JSON map of scene→url) so
 * no key is ever hardcoded. Until then, the mesh gradient shows. Pure.
 */
export type SceneVisual = { gradient: string; image?: string };

// Richer, layered mesh gradients — soft warm light blobs over a base wash.
const GRADIENTS: Record<SceneKey, string> = {
  desk:
    "radial-gradient(38% 32% at 74% 16%, rgba(255,214,140,0.55), transparent 60%)," +
    "radial-gradient(46% 40% at 18% 30%, rgba(245,224,196,0.5), transparent 64%)," +
    "radial-gradient(60% 50% at 60% 92%, rgba(214,180,128,0.35), transparent 70%)," +
    "linear-gradient(158deg, #f8f0e1, #ecdfcb)",
  home:
    "radial-gradient(42% 36% at 28% 22%, rgba(244,196,176,0.5), transparent 62%)," +
    "radial-gradient(40% 34% at 78% 30%, rgba(248,220,200,0.5), transparent 64%)," +
    "radial-gradient(60% 48% at 50% 96%, rgba(214,150,130,0.28), transparent 72%)," +
    "linear-gradient(160deg, #f7ede7, #eedfd6)",
  night:
    "radial-gradient(34% 28% at 78% 14%, rgba(214,222,255,0.5), transparent 60%)," +
    "radial-gradient(50% 44% at 24% 30%, rgba(120,124,180,0.4), transparent 66%)," +
    "radial-gradient(70% 60% at 60% 100%, rgba(70,66,110,0.5), transparent 72%)," +
    "linear-gradient(172deg, #312e4d, #181626)",
  grass:
    "radial-gradient(46% 36% at 50% 8%, rgba(255,236,170,0.55), transparent 56%)," +
    "radial-gradient(50% 44% at 20% 70%, rgba(170,206,140,0.45), transparent 66%)," +
    "radial-gradient(54% 46% at 84% 78%, rgba(150,196,150,0.4), transparent 68%)," +
    "linear-gradient(165deg, #eaf2d8, #cde1bb)",
  highway:
    "radial-gradient(60% 38% at 50% 4%, rgba(255,224,196,0.5), transparent 52%)," +
    "radial-gradient(50% 40% at 22% 40%, rgba(206,178,224,0.5), transparent 66%)," +
    "radial-gradient(60% 50% at 80% 96%, rgba(96,90,140,0.5), transparent 70%)," +
    "linear-gradient(180deg, #ddcdec, #b3a1d2 46%, #635b8c)",
  cafe:
    "radial-gradient(42% 36% at 28% 24%, rgba(236,200,150,0.55), transparent 62%)," +
    "radial-gradient(44% 38% at 80% 34%, rgba(214,168,120,0.45), transparent 64%)," +
    "radial-gradient(60% 50% at 50% 98%, rgba(150,108,72,0.35), transparent 72%)," +
    "linear-gradient(160deg, #eedcc4, #d6bd9f)",
  work:
    "radial-gradient(44% 36% at 70% 16%, rgba(212,224,240,0.6), transparent 62%)," +
    "radial-gradient(46% 40% at 22% 32%, rgba(228,224,236,0.5), transparent 66%)," +
    "radial-gradient(60% 50% at 50% 96%, rgba(150,164,196,0.3), transparent 72%)," +
    "linear-gradient(164deg, #ecf0f6, #d3dbe7)",
  spark:
    "radial-gradient(44% 36% at 50% 16%, rgba(255,234,196,0.5), transparent 60%)," +
    "radial-gradient(46% 40% at 22% 60%, rgba(244,222,236,0.4), transparent 66%)," +
    "radial-gradient(54% 46% at 82% 70%, rgba(214,224,206,0.4), transparent 68%)," +
    "linear-gradient(160deg, #f5efe6, #e9e0d4)",
};

let imageMap: Partial<Record<SceneKey, string>> | null = null;
function loadImageMap(): Partial<Record<SceneKey, string>> {
  if (imageMap) return imageMap;
  try {
    const raw = process.env.NEXT_PUBLIC_SCENE_IMAGES;
    imageMap = raw ? (JSON.parse(raw) as Partial<Record<SceneKey, string>>) : {};
  } catch {
    imageMap = {};
  }
  return imageMap;
}

export function sceneVisual(icon: SceneKey): SceneVisual {
  const gradient = GRADIENTS[icon] ?? GRADIENTS.spark;
  const image = loadImageMap()[icon];
  return image ? { gradient, image } : { gradient };
}
