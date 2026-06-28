"use client";

import React, { useEffect, useRef, useState } from "react";
import Link from "next/link";
import type { LocationType, Opportunity, SeedCategory } from "@/lib/types";
import { useStore, findSeed } from "@/lib/store";
import { recommend } from "@/lib/scoring";
import { buildAmbientContext, guessLocation, ambientLabel, orbScene } from "@/lib/ambient";
import { roundCoarse, isAtHome, isMovingSpeed, type Coords } from "@/lib/geo";
import { buildTrace, type CompletionKind } from "@/lib/traceGenerator";
import { step, type Body } from "@/lib/bubblePhysics";
import { copy } from "@/lib/copy";
import { CategoryGlyph, SceneGlyph } from "./glyphs";
import { useSensors } from "./useSensors";
import { IllustrationArt } from "./illustrationPacks";
import { cx } from "@/lib/utils";
import BreathingCard from "@/components/design/BreathingCard";
import SoftButton from "@/components/design/SoftButton";

type Bubble = {
  id: string;
  seedId: string;
  title: string;
  category: SeedCategory;
  r: number;
  z: number;
  primary: boolean;
  opp?: Opportunity;
};
type SenseState = "idle" | "sensing" | "moving" | "home" | "away" | "offerHome" | "fail";

function isMobileDevice(): boolean {
  if (typeof navigator === "undefined") return false;
  return /Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent) || navigator.maxTouchPoints > 1;
}
function rand(a: number, b: number) {
  return a + Math.random() * (b - a);
}

/**
 * A dreamy field of glass bubbles. The most-fitting wishes settle bigger and
 * brighter near the central orb; lesser ones rest smaller and dimmer across the
 * field. They flow into place on load and stay put — no pointer following. On a
 * phone, granting motion lets the gyro lean the whole cluster *slightly*. Tap one
 * to do it; it dissolves into light and leaves a trace. With `buoyancy`, the field
 * becomes an ocean — wishes float up toward the surface (the bottom edge is the floor).
 */
export default function BubbleField({ buoyancy = false }: { buoyancy?: boolean } = {}) {
  const hydrated = useStore((s) => s.hydrated);
  const seeds = useStore((s) => s.seeds);
  const lastPick = useStore((s) => s.lastPick);
  const addTrace = useStore((s) => s.addTrace);
  const setSeedStatus = useStore((s) => s.setSeedStatus);
  const homeLocation = useStore((s) => s.homeLocation);
  const setHomeLocation = useStore((s) => s.setHomeLocation);
  const { activity, ambient, ambientOn, enableAmbient } = useSensors();
  const senseAround = useStore((s) => s.settings.senseAround);
  const updateSettings = useStore((s) => s.updateSettings);
  const illustrationStyle = useStore((s) => s.settings.illustrationStyle);

  const wrapRef = useRef<HTMLDivElement>(null);
  const elsRef = useRef<Record<string, HTMLButtonElement | null>>({});
  const bodiesRef = useRef<Body[]>([]);
  const homesRef = useRef<Record<string, { x: number; y: number }>>({});
  const tiltRef = useRef<{ gamma: number | null; beta: number | null } | null>(null);
  const rafRef = useRef<number>(0);
  const sizeRef = useRef({ w: 0, h: 0 });
  const phaseRef = useRef<Record<string, number>>({});
  const didRiseRef = useRef(false);
  const lastAccelRef = useRef(0);
  const lastShakeRef = useRef(0);
  const zRef = useRef<Record<string, number>>({});

  const [mounted, setMounted] = useState(false);
  const [now, setNow] = useState<Date | null>(null);
  const [location, setLocation] = useState<LocationType>("anywhere");
  const [bubbles, setBubbles] = useState<Bubble[]>([]);
  const [selected, setSelected] = useState<Bubble | null>(null);
  const [doneSeedIds, setDoneSeedIds] = useState<string[]>([]);
  const [dissolving, setDissolving] = useState<string | null>(null);
  const [justTrace, setJustTrace] = useState("");
  const [gyroOn, setGyroOn] = useState(false);
  const [motes, setMotes] = useState<{ x: number; y: number; s: number; d: number; dur: number }[]>([]);
  const [sense, setSense] = useState<SenseState>("idle");
  const [pendingCoords, setPendingCoords] = useState<Coords | null>(null);

  const ORB_R = 70;

  // sense the moment + build the field
  useEffect(() => {
    const d = new Date();
    const mobile = isMobileDevice();
    setNow(d);
    setLocation(guessLocation(d, mobile));
    setMotes(
      Array.from({ length: 9 }, () => ({
        x: rand(6, 94),
        y: rand(10, 92),
        s: rand(3, 7),
        d: rand(0, 12),
        dur: rand(11, 20),
      }))
    );
    setMounted(true);
  }, []);

  // Sense automatically once opted in (mic permission persists → no re-prompt).
  useEffect(() => {
    if (senseAround) enableAmbient();
  }, [senseAround, enableAmbient]);

  // (re)build bubbles + bodies whenever the field inputs change
  useEffect(() => {
    if (!mounted || !now) return;
    const el = wrapRef.current;
    const w = el?.clientWidth || 360;
    const h = el?.clientHeight || 600;
    sizeRef.current = { w, h };

    const ctx = buildAmbientContext({
      now,
      isMobile: isMobileDevice(),
      locationHint: location,
      energy: lastPick.energy,
      activity,
      ambient,
    });
    const opps = recommend(seeds, ctx, { limit: 4 });
    const primaryIds = new Set(opps.map((o) => o.seedId));
    const ambientSeeds = seeds
      .filter((s) => (s.status === "active" || s.status === "sleeping") && !primaryIds.has(s.id))
      .slice(0, 3);

    const next: Bubble[] = [];
    const bodies: Body[] = [];
    const homes: Record<string, { x: number; y: number }> = {};
    const zmap: Record<string, number> = {};
    const phasemap: Record<string, number> = {};
    // ocean: on first load only, spawn bubbles at the floor so they rise into place
    const rise = buoyancy && !didRiseRef.current;

    opps.forEach((o, i) => {
      const seed = findSeed(seeds, o.seedId);
      if (!seed) return;
      const r = 34 + (3 - i) * 3; // best slightly bigger
      const z = 0.86 + (3 - i) * 0.04; // primaries sit near (crisp)
      const n = opps.length;
      const ang = (-90 + (360 / Math.max(n, 1)) * i) * (Math.PI / 180);
      // buoyancy skin: most relevant float highest (surface); glass skin: ring round orb
      const hx = buoyancy
        ? Math.max(r + 10, Math.min(w - r - 10, w * (0.5 + (i - (n - 1) / 2) * 0.22)))
        : Math.max(r + 8, Math.min(w - r - 8, w / 2 + Math.cos(ang) * (ORB_R + 96)));
      const hy = buoyancy ? h * (0.15 + i * 0.07) : Math.max(r + 8, Math.min(h - r - 8, h / 2 + Math.sin(ang) * (ORB_R + 96)));
      next.push({ id: o.id, seedId: o.seedId, title: seed.title, category: seed.categories[0], r, z, primary: true, opp: o });
      bodies.push({ id: o.id, x: hx, y: rise ? h - r - rand(0, 18) : hy, vx: 0, vy: 0, r, m: r * r });
      homes[o.id] = { x: hx, y: hy };
      zmap[o.id] = z;
      phasemap[o.id] = rand(0, Math.PI * 2);
    });

    ambientSeeds.forEach((seed) => {
      const id = `amb_${seed.id}`;
      const r = rand(15, 22);
      const z = rand(0.25, 0.5); // lesser wishes drift far (soft)
      const hx = rand(r + 6, w - r - 6);
      const hy = buoyancy ? h * 0.6 + rand(0, h * 0.3) : rand(r + 6, h - r - 6);
      next.push({ id, seedId: seed.id, title: seed.title, category: seed.categories[0], r, z, primary: false });
      bodies.push({ id, x: hx, y: rise ? h - r - rand(0, 18) : hy, vx: rand(-8, 8), vy: rand(-8, 8), r, m: r * r });
      homes[id] = { x: hx, y: hy };
      zmap[id] = z;
      phasemap[id] = rand(0, Math.PI * 2);
    });

    if (rise) didRiseRef.current = true;
    bodiesRef.current = bodies;
    homesRef.current = homes;
    zRef.current = zmap;
    phaseRef.current = phasemap;
    setBubbles(next);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mounted, now, seeds, location, lastPick.energy, activity, ambient]);

  // physics loop
  useEffect(() => {
    if (!mounted) return;
    const reduced =
      typeof window !== "undefined" &&
      !!window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches;
    let last = 0;
    const orb = () => {
      const { w, h } = sizeRef.current;
      return { x: w / 2, y: h / 2, r: ORB_R + 18 };
    };
    function frame(t: number) {
      const dt = Math.min(last ? (t - last) / 1000 : 0.016, 0.05);
      last = t;
      const { w, h } = sizeRef.current;
      const bodies = bodiesRef.current;
      const tilt = tiltRef.current;
      const live = gyroOn && tilt;
      // Settle, then rest. A firm spring carries each bubble to its home and holds
      // it there — no drift, no pointer following. On a phone, gyro tilt leans the
      // whole cluster slightly; on desktop there is no input, so they simply rest.
      const leanX = live ? Math.max(-1, Math.min(1, (tilt.gamma ?? 0) / 30)) * 24 : 0;
      const leanY = live ? Math.max(-1, Math.min(1, (tilt.beta ?? 0) / 30)) * 24 : 0;
      for (const b of bodies) {
        const home = homesRef.current[b.id];
        if (!home) continue;
        const bob = buoyancy ? Math.sin(t * 0.0011 + (phaseRef.current[b.id] ?? 0)) * 3 : 0;
        b.vx += (home.x + leanX - b.x) * 2.0 * dt;
        b.vy += (home.y + leanY + bob - b.y) * 2.0 * dt;
      }
      step(bodies, { w, h, gx: 0, gy: 0, dt, anchor: orb(), damping: 0.8, restitution: 0.4 });
      for (const b of bodies) {
        const node = elsRef.current[b.id];
        if (!node) continue;
        node.style.transform = `translate3d(${b.x - b.r}px, ${b.y - b.r}px, 0)`;
      }
      rafRef.current = requestAnimationFrame(frame);
    }
    if (!reduced && (wrapRef.current?.clientWidth ?? 0) > 0) {
      rafRef.current = requestAnimationFrame(frame);
    }
    return () => cancelAnimationFrame(rafRef.current);
  }, [mounted, gyroOn]);

  // Reduced-motion: the rAF loop never runs, so place each bubble at its home
  // once (no animation) — otherwise they'd stack unpositioned in the corner.
  useEffect(() => {
    const reduced =
      typeof window !== "undefined" &&
      !!window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches;
    if (!mounted || !reduced) return;
    for (const b of bodiesRef.current) {
      const home = homesRef.current[b.id];
      if (home) {
        b.x = home.x;
        b.y = home.y;
      }
      const node = elsRef.current[b.id];
      if (node) node.style.transform = `translate3d(${b.x - b.r}px, ${b.y - b.r}px, 0)`;
    }
  }, [mounted, bubbles]);

  if (!mounted || !hydrated || !now) return null;

  const shown = bubbles.filter((b) => !doneSeedIds.includes(b.seedId));
  const scene = orbScene(location, now);

  function complete(b: Bubble, kind: CompletionKind) {
    setSelected(null);
    if (kind === "skipped") return;
    const seed = findSeed(seeds, b.seedId);
    const trace = buildTrace(seed, kind, b.opp?.id);
    addTrace(trace);
    if (seed && kind === "completed") setSeedStatus(seed.id, "sleeping");
    setDissolving(b.id);
    window.setTimeout(() => {
      setDoneSeedIds((d) => [...d, b.seedId]);
      setDissolving(null);
      setJustTrace(trace.text);
    }, 720);
  }

  function enableMotion() {
    const D = (window as unknown as { DeviceOrientationEvent?: { requestPermission?: () => Promise<string> } })
      .DeviceOrientationEvent;
    const start = () => {
      // Smooth the tilt (low-pass) so gravity glides instead of jittering.
      window.addEventListener("deviceorientation", (e) => {
        const g = e.gamma ?? 0;
        const b = e.beta ?? 0;
        const prev = tiltRef.current;
        if (!prev || prev.gamma == null || prev.beta == null) {
          tiltRef.current = { gamma: g, beta: b };
        } else {
          tiltRef.current = { gamma: prev.gamma * 0.82 + g * 0.18, beta: prev.beta * 0.82 + b * 0.18 };
        }
      });
      // Shake to scatter — a sharp jolt flings the bubbles apart.
      window.addEventListener("devicemotion", (e) => {
        const a = e.accelerationIncludingGravity;
        if (!a) return;
        const mag = Math.abs(a.x ?? 0) + Math.abs(a.y ?? 0) + Math.abs(a.z ?? 0);
        const prev = lastAccelRef.current;
        lastAccelRef.current = mag;
        const now = Date.now();
        if (prev && mag - prev > 22 && now - lastShakeRef.current > 900) {
          lastShakeRef.current = now;
          for (const body of bodiesRef.current) {
            body.vx += rand(-280, 280);
            body.vy += rand(-280, 280);
          }
        }
      });
      setGyroOn(true);
    };
    if (D && typeof D.requestPermission === "function") {
      D.requestPermission().then((p) => p === "granted" && start()).catch(() => {});
    } else if (typeof window !== "undefined" && "ondeviceorientation" in window) {
      start();
    }
  }

  const senseText =
    sense === "sensing" ? copy.home.sensing
      : sense === "moving" ? copy.home.sensedMoving
        : sense === "home" ? copy.home.sensedHome
          : sense === "away" ? copy.home.sensedAway
            : sense === "offerHome" ? copy.home.sensedUnknownHome
              : sense === "fail" ? copy.home.sensedFail
                : null;

  const canGyro =
    typeof window !== "undefined" && "DeviceOrientationEvent" in window && isMobileDevice();

  return (
    <div ref={wrapRef} className="relative h-[72dvh] w-full">
      {/* faint drifting motes of light */}
      <div className="dream-motes" aria-hidden>
        {motes.map((m, i) => (
          <span
            key={`mote_${i}`}
            className="mote"
            style={{
              left: `${m.x}%`,
              top: `${m.y}%`,
              width: m.s,
              height: m.s,
              ["--mote-delay"]: `${m.d}s`,
              ["--mote-dur"]: `${m.dur}s`,
            } as React.CSSProperties}
          />
        ))}
      </div>
      {/* drifting glass bubbles */}
      {shown.map((b, i) => (
        <button
          key={b.id}
          ref={(n) => { elsRef.current[b.id] = n; }}
          onClick={() => setSelected(b)}
          aria-label={b.title}
          className={cx(
            "absolute left-0 top-0 flex items-center justify-center rounded-full will-change-transform",
            b.primary ? "glass-liquid glass-iris glass-glint" : "glass glass-faint",
            "relative overflow-hidden",
            // condense out of light on load; switch to dissolve when completed
            dissolving === b.id ? "tdd-dissolve" : "tdd-condense"
          )}
          style={{ width: b.r * 2, height: b.r * 2, ["--gd"]: `${(b.r % 5) * 1.7}s`, animationDelay: dissolving === b.id ? "0ms" : `${(i % 8) * 55}ms`, filter: `blur(${((1 - b.z) * 2.6).toFixed(2)}px) saturate(${(0.88 + b.z * 0.2).toFixed(2)})` } as React.CSSProperties}
        >
          <span className="glass-refract" aria-hidden />
          <CategoryGlyph category={b.category} size={Math.round(b.r)} />
        </button>
      ))}

      {/* a soft warm bloom of light, holding the orb */}
      <div className="orb-bloom" aria-hidden />
      {/* central orb — the AI's read of where you are, glowing */}
      <Link
        href="/now"
        aria-label={copy.home.primary}
        data-orb
        className="glass-liquid orb-glow glass-glint tdd-breathe absolute left-1/2 top-1/2 z-10 flex -translate-x-1/2 -translate-y-1/2 flex-col items-center justify-center gap-1 overflow-hidden rounded-full transition-transform active:scale-[0.97]"
        style={{ width: ORB_R * 2, height: ORB_R * 2 }}
      >
        <span className="glass-refract" aria-hidden />
        <span className="relative">
          <SceneGlyph icon={scene.icon} size={40} />
        </span>
        <span className="serif text-[11px] tracking-[0.14em] text-[var(--text-secondary)]">
          {scene.label}
        </span>
      </Link>

      {/* the quiet overlay: wordmark line + controls (out of the bubbles' way) */}
      <div className="pointer-events-none absolute inset-x-0 top-0 z-20 flex flex-col items-center gap-2 pt-1">
        <button
          onClick={senseLocation}
          className="pointer-events-auto text-[12.5px] tracking-[0.12em] text-[var(--text-secondary)] transition-opacity hover:opacity-75"
        >
          {senseText ?? ambientLabel(now, location, { activity, ambient })}
        </button>
        {sense === "offerHome" && pendingCoords && (
          <button
            onClick={() => { setHomeLocation(pendingCoords); setLocation("home"); setSense("home"); }}
            className="glass pointer-events-auto rounded-full px-4 py-1.5 text-[12px] text-[var(--text)]"
          >
            {copy.home.setHome}
          </button>
        )}
      </div>

      <div className="pointer-events-none absolute inset-x-0 bottom-0 z-20 flex flex-col items-center gap-3 pb-1">
        {justTrace && (
          <p className="serif max-w-[270px] text-center text-[14px] leading-relaxed text-[var(--text-secondary)]">
            {justTrace}
          </p>
        )}
        <div className="pointer-events-auto flex flex-wrap items-center justify-center gap-3">
          {canGyro && !gyroOn && (
            <button
              onClick={enableMotion}
              className="glass rounded-full px-4 py-2 text-[12px] text-[var(--text-secondary)]"
            >
              {buoyancy ? copy.home.feelCurrent : copy.home.feelGravity}
            </button>
          )}
          {!ambientOn && (
            <button
              onClick={() => { updateSettings({ senseAround: true }); enableAmbient(); }}
              className="glass rounded-full px-4 py-2 text-[12px] text-[var(--text-secondary)]"
            >
              {copy.home.senseAround}
            </button>
          )}
          <Link
            href="/add"
            aria-label="接住一个新愿望"
            className="glass flex h-11 w-11 items-center justify-center rounded-full text-[20px] text-[var(--text-secondary)] transition-transform active:scale-[0.95]"
          >
            +
          </Link>
        </div>
      </div>

      <div className="dream-vignette" aria-hidden />

      {/* tap-a-bubble sheet */}
      {selected && (() => {
        const seed = findSeed(seeds, selected.seedId);
        if (!seed) return null;
        return (
          <div className="fixed inset-0 z-50 flex items-end justify-center sm:items-center" role="dialog" aria-modal="true">
            <button aria-label="关闭" onClick={() => setSelected(null)} className="absolute inset-0 bg-black/30 backdrop-blur-[2px]" />
            <BreathingCard rise className="relative m-3 flex w-full max-w-md flex-col gap-4" style={{ paddingBottom: "calc(env(safe-area-inset-bottom) + 1.25rem)" }}>
              <span className="mx-auto h-28 w-48 overflow-hidden rounded-2xl bg-[#f1ece2]">
                <IllustrationArt style={illustrationStyle} />
              </span>
              <div className="flex items-center gap-2">
                <CategoryGlyph category={seed.categories[0]} size={24} />
                <h3 className="serif text-[19px] font-medium text-[var(--text)]">{seed.title}</h3>
              </div>
              <p className="text-[14px] leading-relaxed text-[var(--text-secondary)]">
                {selected.opp?.suggestedAction ?? seed.minimumAction}
              </p>
              {selected.opp && (
                <div className="rounded-2xl bg-[var(--surface-soft)] p-3 text-[13px] leading-relaxed text-[var(--text-secondary)]">
                  {selected.opp.reason}
                </div>
              )}
              <div className="flex flex-col gap-2">
                <SoftButton full onClick={() => complete(selected, "completed")}>{copy.completion.done}</SoftButton>
                <SoftButton full variant="soft" onClick={() => complete(selected, "partial")}>{copy.completion.partial}</SoftButton>
                <SoftButton full variant="ghost" onClick={() => setSelected(null)}>{copy.home.bubbleLater}</SoftButton>
              </div>
            </BreathingCard>
          </div>
        );
      })()}
    </div>
  );

  function senseLocation() {
    if (typeof navigator === "undefined" || !navigator.geolocation) { setSense("fail"); return; }
    setSense("sensing");
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const coords = roundCoarse({ lat: pos.coords.latitude, lng: pos.coords.longitude });
        if (isMovingSpeed(pos.coords.speed)) { setLocation("transit"); setSense("moving"); }
        else if (homeLocation) {
          if (isAtHome(homeLocation, coords)) { setLocation("home"); setSense("home"); }
          else { setLocation("outdoor"); setSense("away"); }
        } else { setPendingCoords(coords); setSense("offerHome"); }
      },
      () => setSense("fail"),
      { enableHighAccuracy: true, maximumAge: 0, timeout: 8000 }
    );
  }
}

