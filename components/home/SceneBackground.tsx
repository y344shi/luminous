"use client";

import { useEffect, useState } from "react";
import { guessLocation, orbScene } from "@/lib/ambient";
import { sceneVisual, type SceneVisual } from "@/lib/sceneBackground";

function isMobileDevice(): boolean {
  if (typeof navigator === "undefined") return false;
  return /Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent) || navigator.maxTouchPoints > 1;
}

/**
 * A warm wallpaper behind the bubbles that reflects the sensed scene (desk /
 * grass / highway / café / night). A theme-tinted scrim keeps the glass and text
 * legible. Gradient base now; a high-res / 3D image can layer in later
 * (docs/scene-library.md). Computed client-side to avoid hydration mismatch.
 */
export default function SceneBackground() {
  const [v, setV] = useState<SceneVisual | null>(null);

  useEffect(() => {
    const now = new Date();
    const scene = orbScene(guessLocation(now, isMobileDevice()), now);
    setV(sceneVisual(scene.icon));
  }, []);

  if (!v) return null;

  return (
    <div aria-hidden className="absolute inset-0 z-0 overflow-hidden">
      <div
        className="absolute inset-0 transition-[background] duration-[1200ms] ease-in-out"
        style={{ background: v.gradient }}
      />
      {/* curated photo for this scene, when configured (NEXT_PUBLIC_SCENE_IMAGES) */}
      {v.image && (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={v.image}
          alt=""
          className="absolute inset-0 h-full w-full object-cover opacity-55 [filter:blur(2px)_saturate(1.05)] mix-blend-soft-light"
        />
      )}
      {/* theme scrim — ties the wallpaper to the active theme + keeps legibility */}
      <div
        className="absolute inset-0"
        style={{ background: "color-mix(in srgb, var(--bg) 44%, transparent)" }}
      />
    </div>
  );
}
