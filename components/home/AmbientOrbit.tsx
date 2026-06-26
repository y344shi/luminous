"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import type { LocationType, Opportunity } from "@/lib/types";
import { useStore, findSeed } from "@/lib/store";
import { recommend } from "@/lib/scoring";
import { buildAmbientContext, guessLocation, ambientLabel } from "@/lib/ambient";
import { roundCoarse, isAtHome, isMovingSpeed, type Coords } from "@/lib/geo";
import { buildTrace, type CompletionKind } from "@/lib/traceGenerator";
import { categoryMeta } from "@/lib/categoryMeta";
import { copy } from "@/lib/copy";
import { cx } from "@/lib/utils";
import BreathingCard from "@/components/design/BreathingCard";
import SoftButton from "@/components/design/SoftButton";

// Circular layout geometry (px).
const BOX = 300;
const CENTER = BOX / 2;
const CENTER_DIAM = 136;
const BUBBLE = 62;
const RADIUS = CENTER / 1 - BUBBLE / 2 - 8; // bubbles sit just inside the edge

const floatClass = ["tdd-float-a", "tdd-float-b", "tdd-float-c"];
type SenseState = "idle" | "sensing" | "moving" | "home" | "away" | "offerHome" | "fail";

function isMobileDevice(): boolean {
  if (typeof navigator === "undefined") return false;
  return /Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent) || navigator.maxTouchPoints > 1;
}

/**
 * The friction-free Home: a single breathing centre (the deliberate path, →/now)
 * surrounded by gently orbiting opportunity bubbles (the proactive path). Almost
 * no text; the only control is the ambient line, which you can tap to sense where
 * you are. Precise pickers live in /now — Home stays calm.
 */
export default function AmbientOrbit() {
  const router = useRouter();
  const hydrated = useStore((s) => s.hydrated);
  const seeds = useStore((s) => s.seeds);
  const lastPick = useStore((s) => s.lastPick);
  const addTrace = useStore((s) => s.addTrace);
  const setSeedStatus = useStore((s) => s.setSeedStatus);
  const homeLocation = useStore((s) => s.homeLocation);
  const setHomeLocation = useStore((s) => s.setHomeLocation);

  const [mounted, setMounted] = useState(false);
  const [now, setNow] = useState<Date | null>(null);
  const [isMobile, setIsMobile] = useState(false);
  const [location, setLocation] = useState<LocationType>("anywhere");
  const [sense, setSense] = useState<SenseState>("idle");
  const [pendingCoords, setPendingCoords] = useState<Coords | null>(null);
  const [selected, setSelected] = useState<Opportunity | null>(null);
  const [doneSeedIds, setDoneSeedIds] = useState<string[]>([]);
  const [justTrace, setJustTrace] = useState("");

  useEffect(() => {
    const d = new Date();
    const mobile = isMobileDevice();
    setNow(d);
    setIsMobile(mobile);
    setLocation(guessLocation(d, mobile));
    setMounted(true);
  }, []);

  const opportunities = useMemo(() => {
    if (!now) return [];
    const ctx = buildAmbientContext({ now, isMobile, locationHint: location, energy: lastPick.energy });
    return recommend(seeds, ctx, { limit: 4 });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [seeds, location, isMobile, now, lastPick.energy]);

  if (!mounted || !hydrated || !now) return null;

  const visible = opportunities.filter((o) => !doneSeedIds.includes(o.seedId)).slice(0, 4);
  const n = Math.max(visible.length, 1);

  function complete(o: Opportunity, kind: CompletionKind) {
    const seed = findSeed(seeds, o.seedId);
    if (kind !== "skipped") {
      const trace = buildTrace(seed, kind, o.id);
      addTrace(trace);
      if (seed && kind === "completed") setSeedStatus(seed.id, "sleeping");
      setJustTrace(trace.text);
      setDoneSeedIds((d) => [...d, o.seedId]);
    }
    setSelected(null);
  }

  const senseText =
    sense === "sensing" ? copy.home.sensing
      : sense === "moving" ? copy.home.sensedMoving
        : sense === "home" ? copy.home.sensedHome
          : sense === "away" ? copy.home.sensedAway
            : sense === "offerHome" ? copy.home.sensedUnknownHome
              : sense === "fail" ? copy.home.sensedFail
                : null;

  return (
    <div className="flex flex-col items-center gap-5">
      {/* one quiet line — tap to sense where you are */}
      <button
        onClick={senseLocation}
        className="text-[13px] tracking-wide text-[var(--text-secondary)] transition-opacity hover:opacity-80"
      >
        {senseText ?? ambientLabel(now, location)}
      </button>

      {sense === "offerHome" && pendingCoords && (
        <button
          onClick={() => {
            setHomeLocation(pendingCoords);
            setLocation("home");
            setSense("home");
          }}
          className="rounded-full bg-[var(--accent-soft)] px-4 py-1.5 text-[12px] text-[var(--text)]"
        >
          {copy.home.setHome}
        </button>
      )}

      {/* the orbit */}
      <div className="relative" style={{ width: BOX, height: BOX, maxWidth: "92vw" }}>
        {/* centre — the deliberate path */}
        <Link
          href="/now"
          aria-label={copy.home.primary}
          className="tdd-breathe absolute left-1/2 top-1/2 flex -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-full bg-[var(--accent)] text-[var(--on-accent)] shadow-[var(--shadow-card)] transition-transform active:scale-[0.97]"
          style={{ width: CENTER_DIAM, height: CENTER_DIAM }}
        >
          <span className="text-center text-[16px] font-medium leading-snug">
            现在
            <br />
            别消失
          </span>
        </Link>

        {/* orbiting opportunities */}
        {visible.map((o, i) => {
          const seed = findSeed(seeds, o.seedId);
          if (!seed) return null;
          const angle = (-90 + (360 / n) * i) * (Math.PI / 180);
          const left = CENTER + RADIUS * Math.cos(angle);
          const top = CENTER + RADIUS * Math.sin(angle);
          return (
            <div
              key={o.id}
              className="absolute flex -translate-x-1/2 -translate-y-1/2 flex-col items-center gap-1"
              style={{ left: `${(left / BOX) * 100}%`, top: `${(top / BOX) * 100}%` }}
            >
              <button
                onClick={() => setSelected(o)}
                aria-label={seed.title}
                className={cx(
                  "flex items-center justify-center rounded-full border border-[var(--border)] bg-[var(--surface)] shadow-[var(--shadow-card)] transition-transform active:scale-[0.94]",
                  floatClass[i % floatClass.length]
                )}
                style={{ width: BUBBLE, height: BUBBLE, animationDelay: `${i * 0.5}s` }}
              >
                <span className="text-[22px]" aria-hidden>
                  {categoryMeta[seed.categories[0]]?.emoji}
                </span>
              </button>
              <span className="max-w-[78px] text-center text-[10px] leading-tight text-[var(--text-muted)]">
                {seed.title}
              </span>
            </div>
          );
        })}
      </div>

      {/* the just-made trace, quietly */}
      {justTrace && (
        <p className="tdd-rise max-w-[260px] text-center text-[14px] leading-relaxed text-[var(--text-secondary)]">
          {justTrace}
        </p>
      )}

      {/* one small way to add a wish */}
      <Link
        href="/add"
        aria-label="接住一个新愿望"
        className="mt-1 flex h-11 w-11 items-center justify-center rounded-full border border-[var(--border)] bg-[var(--surface)] text-[20px] text-[var(--text-secondary)] shadow-[var(--shadow-card)] transition-transform active:scale-[0.95]"
      >
        +
      </Link>

      {/* tap-a-bubble sheet */}
      {selected && (() => {
        const seed = findSeed(seeds, selected.seedId);
        if (!seed) return null;
        return (
          <div className="fixed inset-0 z-50 flex items-end justify-center sm:items-center" role="dialog" aria-modal="true">
            <button aria-label="关闭" onClick={() => setSelected(null)} className="absolute inset-0 bg-black/30 backdrop-blur-[2px]" />
            <BreathingCard rise className="relative m-3 flex w-full max-w-md flex-col gap-4" style={{ paddingBottom: "calc(env(safe-area-inset-bottom) + 1.25rem)" }}>
              <div className="flex items-center gap-2">
                <span className="text-xl">{categoryMeta[seed.categories[0]]?.emoji}</span>
                <h3 className="text-[18px] font-medium text-[var(--text)]">{seed.title}</h3>
              </div>
              <p className="text-[14px] leading-relaxed text-[var(--text-secondary)]">{selected.suggestedAction}</p>
              <div className="rounded-2xl bg-[var(--surface-soft)] p-3 text-[13px] leading-relaxed text-[var(--text-secondary)]">
                {selected.reason}
              </div>
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
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      setSense("fail");
      return;
    }
    setSense("sensing");
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const coords = roundCoarse({ lat: pos.coords.latitude, lng: pos.coords.longitude });
        if (isMovingSpeed(pos.coords.speed)) {
          setLocation("transit");
          setSense("moving");
        } else if (homeLocation) {
          if (isAtHome(homeLocation, coords)) {
            setLocation("home");
            setSense("home");
          } else {
            setLocation("outdoor");
            setSense("away");
          }
        } else {
          setPendingCoords(coords);
          setSense("offerHome");
        }
      },
      () => setSense("fail"),
      { enableHighAccuracy: true, maximumAge: 0, timeout: 8000 }
    );
  }
}
