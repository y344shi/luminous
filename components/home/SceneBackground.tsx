"use client";

import { useEffect, useRef, useState } from "react";
import { guessLocation, orbScene } from "@/lib/ambient";
import { sceneVisual, type SceneVisual } from "@/lib/sceneBackground";
import { useStore } from "@/lib/store";
import { roundCoarse } from "@/lib/geo";
import {
  buildOpenMeteoUrl,
  parseOpenMeteo,
  classifyWeather,
  weatherTint,
  type WeatherKind,
} from "@/lib/weather";

function isMobileDevice(): boolean {
  if (typeof navigator === "undefined") return false;
  return /Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent) || navigator.maxTouchPoints > 1;
}

/**
 * A warm wallpaper behind the bubbles that reflects the sensed scene, with a
 * light **parallax depth**: a far gradient layer and a nearer light layer drift
 * by different amounts as you move the pointer or tilt the device — a cheap "3D"
 * without a heavy engine. A theme scrim keeps the glass + text legible. A curated
 * photo can layer in (NEXT_PUBLIC_SCENE_IMAGES). Reduced-motion: no parallax.
 */
export default function SceneBackground() {
  const [v, setV] = useState<SceneVisual | null>(null);
  const [weather, setWeather] = useState<WeatherKind | null>(null);
  const homeLocation = useStore((s) => s.homeLocation);
  const farRef = useRef<HTMLDivElement>(null);
  const nearRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const now = new Date();
    const scene = orbScene(guessLocation(now, isMobileDevice()), now);
    setV(sceneVisual(scene.icon));
  }, []);

  // Coarse weather tint — only when a home location was already saved (consented).
  useEffect(() => {
    if (!homeLocation) return;
    let cancelled = false;
    fetch(buildOpenMeteoUrl(roundCoarse(homeLocation)))
      .then((r) => (r.ok ? r.json() : null))
      .then((j) => {
        const code = parseOpenMeteo(j);
        if (!cancelled && code != null) setWeather(classifyWeather(code));
      })
      .catch(() => {
        /* weather is a nicety; ignore failures */
      });
    return () => {
      cancelled = true;
    };
  }, [homeLocation]);

  useEffect(() => {
    if (!v) return;
    const reduced = !!window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches;
    if (reduced) return;

    let raf = 0;
    let tx = 0;
    let ty = 0; // -1..1
    const apply = () => {
      if (farRef.current) farRef.current.style.transform = `translate3d(${tx * -7}px, ${ty * -7}px, 0)`;
      if (nearRef.current) nearRef.current.style.transform = `translate3d(${tx * 18}px, ${ty * 18}px, 0)`;
      raf = 0;
    };
    const schedule = () => {
      if (!raf) raf = requestAnimationFrame(apply);
    };
    const onPointer = (e: PointerEvent) => {
      tx = e.clientX / window.innerWidth - 0.5;
      ty = e.clientY / window.innerHeight - 0.5;
      schedule();
    };
    const onTilt = (e: DeviceOrientationEvent) => {
      tx = Math.max(-1, Math.min(1, (e.gamma ?? 0) / 45));
      ty = Math.max(-1, Math.min(1, (e.beta ?? 0) / 45));
      schedule();
    };
    window.addEventListener("pointermove", onPointer, { passive: true });
    window.addEventListener("deviceorientation", onTilt);
    return () => {
      window.removeEventListener("pointermove", onPointer);
      window.removeEventListener("deviceorientation", onTilt);
      if (raf) cancelAnimationFrame(raf);
    };
  }, [v]);

  if (!v) return null;

  return (
    <div aria-hidden className="absolute inset-0 z-0 overflow-hidden">
      {/* far layer — the scene wallpaper */}
      <div
        ref={farRef}
        className="absolute inset-[-9%] transition-[background] duration-[1200ms] ease-in-out will-change-transform"
        style={{ background: v.gradient }}
      />
      {/* near layer — soft light blobs that parallax more */}
      <div
        ref={nearRef}
        className="absolute inset-[-14%] will-change-transform"
        style={{
          background:
            "radial-gradient(26% 22% at 22% 24%, rgba(255,255,255,0.4), transparent 60%)," +
            "radial-gradient(30% 26% at 82% 30%, color-mix(in srgb, var(--accent) 26%, transparent), transparent 64%)",
        }}
      />
      {/* curated photo for this scene, when configured */}
      {v.image && (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={v.image}
          alt=""
          className="absolute inset-0 h-full w-full object-cover opacity-55 [filter:blur(2px)_saturate(1.05)] mix-blend-soft-light"
        />
      )}
      {/* weather veil — a soft tint reacting to rain / cloud / snow / fog */}
      {weather && weatherTint(weather) && (
        <div
          className="absolute inset-0 transition-opacity duration-[1500ms]"
          style={{ background: weatherTint(weather) as string }}
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
