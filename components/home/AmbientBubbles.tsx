"use client";

import { useEffect, useMemo, useState } from "react";
import type { LocationType, Opportunity } from "@/lib/types";
import { useStore, findSeed } from "@/lib/store";
import { recommend } from "@/lib/scoring";
import { buildAmbientContext, guessLocation, ambientLabel } from "@/lib/ambient";
import { buildTrace, type CompletionKind } from "@/lib/traceGenerator";
import { categoryMeta } from "@/lib/categoryMeta";
import { copy } from "@/lib/copy";
import { cx } from "@/lib/utils";
import BreathingCard from "@/components/design/BreathingCard";
import SoftButton from "@/components/design/SoftButton";
import { ChipGroup, locationOptions } from "@/components/context/Pickers";

const floatClass = ["tdd-float-a", "tdd-float-b", "tdd-float-c"];
const bubbleSize = ["text-[15px]", "text-[16px]", "text-[15px]", "text-[17px]"];

type SenseState = "idle" | "sensing" | "moving" | "still" | "fail";

function isMobileDevice(): boolean {
  if (typeof navigator === "undefined") return false;
  return /Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent) || navigator.maxTouchPoints > 1;
}

export default function AmbientBubbles() {
  const hydrated = useStore((s) => s.hydrated);
  const seeds = useStore((s) => s.seeds);
  const lastPick = useStore((s) => s.lastPick);
  const addTrace = useStore((s) => s.addTrace);
  const setSeedStatus = useStore((s) => s.setSeedStatus);

  const [mounted, setMounted] = useState(false);
  const [now, setNow] = useState<Date | null>(null);
  const [isMobile, setIsMobile] = useState(false);
  const [location, setLocation] = useState<LocationType>("anywhere");
  const [sense, setSense] = useState<SenseState>("idle");

  const [selected, setSelected] = useState<Opportunity | null>(null);
  const [doneSeedIds, setDoneSeedIds] = useState<string[]>([]);
  const [justTrace, setJustTrace] = useState<string>("");

  // Sense the moment on the client only (Date + navigator) — no SSR mismatch.
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

  const visible = opportunities.filter((o) => !doneSeedIds.includes(o.seedId));

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

  return (
    <section className="flex flex-col gap-3">
      <p className="px-1 text-[13px] text-[var(--text-secondary)]">
        {ambientLabel(now, location)}
      </p>

      {justTrace && (
        <BreathingCard soft rise className="text-center">
          <p className="py-2 text-[15px] leading-relaxed text-[var(--text)]">{justTrace}</p>
        </BreathingCard>
      )}

      {visible.length > 0 ? (
        <>
          <p className="px-1 text-[14px] text-[var(--text)]">{copy.home.bubblesLead}</p>
          <div className="flex flex-wrap items-center gap-3 py-1">
            {visible.map((o, i) => {
              const seed = findSeed(seeds, o.seedId);
              if (!seed) return null;
              return (
                <button
                  key={o.id}
                  onClick={() => setSelected(o)}
                  className={cx(
                    "tdd-rise flex items-center gap-2 rounded-[40px] border border-[var(--border)] bg-[var(--accent-soft)] px-4 py-3 text-[var(--text)] shadow-[var(--shadow-card)] transition-transform active:scale-[0.97]",
                    floatClass[i % floatClass.length],
                    bubbleSize[i % bubbleSize.length]
                  )}
                  style={{ animationDelay: `${i * 0.4}s` }}
                >
                  <span aria-hidden>{categoryMeta[seed.categories[0]]?.emoji}</span>
                  <span className="font-medium">{seed.title}</span>
                </button>
              );
            })}
          </div>
        </>
      ) : (
        <p className="px-1 text-[14px] text-[var(--text-secondary)]">{copy.home.bubblesEmpty}</p>
      )}

      {/* Movement sense (opt-in) + correctable location */}
      <div className="flex flex-col gap-2 pt-1">
        {sense === "idle" && (
          <button
            onClick={senseMovement}
            className="self-start text-[12px] text-[var(--text-muted)] underline-offset-4 hover:underline"
          >
            {copy.home.senseMove}
          </button>
        )}
        {sense !== "idle" && (
          <p className="px-1 text-[12px] text-[var(--text-muted)]">
            {sense === "sensing"
              ? copy.home.sensing
              : sense === "moving"
                ? copy.home.sensedMoving
                : sense === "still"
                  ? copy.home.sensedStill
                  : copy.home.sensedFail}
          </p>
        )}
        <details className="group">
          <summary className="cursor-pointer list-none text-[12px] text-[var(--text-muted)]">
            {copy.home.locationCorrect}
          </summary>
          <div className="pt-2">
            <ChipGroup options={locationOptions} value={location} onChange={setLocation} />
          </div>
        </details>
      </div>

      {/* Tap-a-bubble action sheet */}
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
                <SoftButton full onClick={() => complete(selected, "completed")}>
                  {copy.completion.done}
                </SoftButton>
                <SoftButton full variant="soft" onClick={() => complete(selected, "partial")}>
                  {copy.completion.partial}
                </SoftButton>
                <SoftButton full variant="ghost" onClick={() => setSelected(null)}>
                  {copy.home.bubbleLater}
                </SoftButton>
              </div>
            </BreathingCard>
          </div>
        );
      })()}
    </section>
  );

  function senseMovement() {
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      setSense("fail");
      return;
    }
    setSense("sensing");
    let best: number | null = null;
    const id = navigator.geolocation.watchPosition(
      (pos) => {
        if (pos.coords.speed != null) best = Math.max(best ?? 0, pos.coords.speed);
      },
      () => {
        navigator.geolocation.clearWatch(id);
        setSense("fail");
      },
      { enableHighAccuracy: true, maximumAge: 0, timeout: 6000 }
    );
    window.setTimeout(() => {
      navigator.geolocation.clearWatch(id);
      if (best != null && best > 1.2) {
        setLocation("transit");
        setSense("moving");
      } else if (best != null) {
        setSense("still");
      } else {
        setSense("fail");
      }
    }, 5000);
  }
}
