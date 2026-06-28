"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import type { LocationType, Opportunity } from "@/lib/types";
import { useStore, findSeed } from "@/lib/store";
import { recommend } from "@/lib/scoring";
import { buildAmbientContext, guessLocation, ambientLabel } from "@/lib/ambient";
import { buildTrace, type CompletionKind } from "@/lib/traceGenerator";
import { copy } from "@/lib/copy";
import { completeFeedback } from "@/lib/feedback";
import { cx } from "@/lib/utils";
import { CategoryGlyph } from "../shared/glyphs";
import PressedFlower from "./PressedFlower";
import { useSensors } from "../shared/useSensors";
import { useDwell } from "../shared/useDwell";
import { useWeather, isGoodOutdoorWeather } from "../shared/useWeather";
import { useBattery } from "../shared/useBattery";
import BreathingCard from "@/components/design/BreathingCard";
import SoftButton from "@/components/design/SoftButton";

function isMobileDevice(): boolean {
  if (typeof navigator === "undefined") return false;
  return /Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent) || navigator.maxTouchPoints > 1;
}

const tilts = ["-1.6deg", "1.4deg", "-0.8deg", "2deg"];

/**
 * The "Calm Ritual" Home — a contrasting aesthetic to the glass field. A warm
 * ruled-paper sheet; today's wishes are hand-laid notes you can do, written in a
 * brush-script face. Tactile, slow, intentional. Same loop underneath: tap a
 * note → do a little → it leaves a trace line on the page.
 */
export default function PaperHome() {
  const hydrated = useStore((s) => s.hydrated);
  const seeds = useStore((s) => s.seeds);
  const lastPick = useStore((s) => s.lastPick);
  const addTrace = useStore((s) => s.addTrace);
  const setSeedStatus = useStore((s) => s.setSeedStatus);
  const soundEnabled = useStore((s) => s.settings.soundEnabled);
  const { activity, ambient, ambientOn, enableAmbient } = useSensors();
  const senseAround = useStore((s) => s.settings.senseAround);
  const updateSettings = useStore((s) => s.updateSettings);
  const homeLocation = useStore((s) => s.homeLocation);
  const deskMinutesToday = useDwell();
  const weatherKind = useWeather(homeLocation);
  const isOutdoorWeatherGood = isGoodOutdoorWeather(weatherKind);
  const batteryLow = useBattery();

  const [mounted, setMounted] = useState(false);
  const [now, setNow] = useState<Date | null>(null);
  const [location, setLocation] = useState<LocationType>("anywhere");
  const [opps, setOpps] = useState<Opportunity[]>([]);
  const [selected, setSelected] = useState<Opportunity | null>(null);
  const [doneSeedIds, setDoneSeedIds] = useState<string[]>([]);
  const [justTrace, setJustTrace] = useState("");

  useEffect(() => {
    const d = new Date();
    const loc = guessLocation(d, isMobileDevice());
    setNow(d);
    setLocation(loc);
    setMounted(true);
  }, []);

  // Sense automatically once opted in (mic permission persists → no re-prompt).
  useEffect(() => {
    if (senseAround) enableAmbient();
  }, [senseAround, enableAmbient]);

  useEffect(() => {
    if (!mounted || !now) return;
    const ctx = buildAmbientContext({ now, isMobile: isMobileDevice(), locationHint: location, energy: lastPick.energy, activity, ambient, deskMinutesToday, isOutdoorWeatherGood, batteryLow });
    setOpps(recommend(seeds, ctx, { limit: 4 }));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mounted, now, seeds, location, lastPick.energy, activity, ambient, deskMinutesToday, isOutdoorWeatherGood, batteryLow]);

  if (!mounted || !hydrated || !now) return null;
  const shown = opps.filter((o) => !doneSeedIds.includes(o.seedId));

  function complete(o: Opportunity, kind: CompletionKind) {
    setSelected(null);
    if (kind === "skipped") return;
    const seed = findSeed(seeds, o.seedId);
    const trace = buildTrace(seed, kind, o.id);
    addTrace(trace);
    if (seed && kind === "completed") setSeedStatus(seed.id, "sleeping");
    completeFeedback(soundEnabled);
    setJustTrace(trace.text);
    setDoneSeedIds((d) => [...d, o.seedId]);
  }

  return (
    <div className="paper relative -mx-5 min-h-[82dvh] px-7 pb-12 pt-6">
      <header className="pl-7">
        <h1 className="hand text-[30px] leading-tight text-[var(--text)]">今天别消失</h1>
        <p className="hand mt-1 text-[15px] text-[var(--text-secondary)]">{ambientLabel(now, location, { activity, ambient, deskMinutesToday }, weatherKind)}</p>
      </header>

      <p className="hand mt-6 pl-7 text-[16px] text-[var(--text-secondary)]">也许现在，可以做一点这些——</p>

      <ul aria-label="也许现在可以做的小事" className="mt-3 flex flex-col gap-5 pl-7 pr-2">
        {shown.map((o, i) => {
          const seed = findSeed(seeds, o.seedId);
          if (!seed) return null;
          return (
            <li key={o.id} style={{ transform: `rotate(${tilts[i % tilts.length]})` }}>
              <button
                onClick={() => setSelected(o)}
                aria-label={`${seed.title}，${o.suggestedAction}`}
                style={{ animationDelay: `${i * 90}ms` }}
                className="paper-note tdd-rise flex w-full items-start gap-3 rounded-[4px] p-4 text-left transition-transform active:scale-[0.99]"
              >
                <PressedFlower
                  category={seed.categories[0]}
                  className="pointer-events-none absolute right-2.5 top-2.5 text-[var(--accent-text)] opacity-25"
                />
                <CategoryGlyph category={seed.categories[0]} size={22} className="mt-0.5 text-[var(--accent-text)]" />
                <span className="flex flex-col">
                  <span className="hand text-[19px] leading-snug text-[var(--text)]">{seed.title}</span>
                  <span className="text-[13px] leading-relaxed text-[var(--text-secondary)]">{o.suggestedAction}</span>
                </span>
              </button>
            </li>
          );
        })}
      </ul>

      {justTrace && (
        <p role="status" className="hand tdd-rise mt-7 pl-7 text-[17px] leading-relaxed text-[var(--accent-text)]">
          ✍ {justTrace}
        </p>
      )}

      <div className="mt-9 flex flex-wrap items-center gap-4 pl-7">
        <Link
          href="/now"
          className="hand rounded-[4px] border border-[var(--text)]/15 bg-[var(--surface)] px-5 py-2.5 text-[16px] text-[var(--text)] shadow-[0_4px_12px_rgba(0,0,0,0.08)]"
        >
          {copy.home.primary}
        </Link>
        <Link href="/add" aria-label="接住一个新愿望" className="hand text-[22px] text-[var(--text-secondary)]">＋</Link>
        {!ambientOn && (
          <button
            onClick={() => { updateSettings({ senseAround: true }); enableAmbient(); }}
            className="hand rounded-[4px] border border-[var(--text)]/15 bg-[var(--surface)] px-3.5 py-2 text-[13px] text-[var(--text-secondary)]"
          >
            {copy.home.senseAround}
          </button>
        )}
      </div>

      {selected && (() => {
        const seed = findSeed(seeds, selected.seedId);
        if (!seed) return null;
        return (
          <div className="fixed inset-0 z-50 flex items-end justify-center sm:items-center" role="dialog" aria-modal="true">
            <button aria-label="关闭" onClick={() => setSelected(null)} className="absolute inset-0 bg-black/30" />
            <BreathingCard rise className="relative m-3 flex w-full max-w-md flex-col gap-4">
              <div className="flex items-center gap-2">
                <CategoryGlyph category={seed.categories[0]} size={22} />
                <h3 className="hand text-[20px] font-medium text-[var(--text)]">{seed.title}</h3>
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
}
