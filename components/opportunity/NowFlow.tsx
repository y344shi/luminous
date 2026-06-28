"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import type { Mood, Energy, Opportunity, LocationType } from "@/lib/types";
import { useStore, findSeed } from "@/lib/store";
import { buildContext } from "@/lib/context";
import { recommend } from "@/lib/scoring";
import { useSensors } from "@/components/home/shared/useSensors";
import { useDwell } from "@/components/home/shared/useDwell";
import { useWeather, isGoodOutdoorWeather } from "@/components/home/shared/useWeather";
import { useBattery } from "@/components/home/shared/useBattery";
import { buildTrace, buildRestTrace, type CompletionKind } from "@/lib/traceGenerator";
import { copy } from "@/lib/copy";
import { completeFeedback } from "@/lib/feedback";
import BreathingCard from "@/components/design/BreathingCard";
import SoftButton from "@/components/design/SoftButton";
import EmptyState from "@/components/design/EmptyState";
import OpportunityCard from "./OpportunityCard";
import {
  ChipGroup,
  ToggleChip,
  moodOptions,
  energyOptions,
  freeOptions,
  locationOptions,
} from "@/components/context/Pickers";

type Step = "context" | "list" | "completion" | "trace";

export default function NowFlow() {
  const router = useRouter();
  const seeds = useStore((s) => s.seeds);
  const setOpportunities = useStore((s) => s.setOpportunities);
  const addTrace = useStore((s) => s.addTrace);
  const updateTrace = useStore((s) => s.updateTrace);
  const updateSeed = useStore((s) => s.updateSeed);
  const soundEnabled = useStore((s) => s.settings.soundEnabled);
  const hydrated = useStore((s) => s.hydrated);
  const lastPick = useStore((s) => s.lastPick);
  const homeLocation = useStore((s) => s.homeLocation);
  const { activity, ambient } = useSensors();
  const deskMinutesToday = useDwell();
  const weatherKind = useWeather(homeLocation);
  const batteryLow = useBattery();
  const illustrationStyle = useStore((s) => s.settings.illustrationStyle);
  const rememberPick = useStore((s) => s.rememberPick);

  const [step, setStep] = useState<Step>("context");
  const [mood, setMood] = useState<Mood>();
  const [energy, setEnergy] = useState<Energy>();
  const [freeMinutes, setFreeMinutes] = useState<number | undefined>(undefined);
  const [freeTouched, setFreeTouched] = useState(false);
  const [locationHint, setLocationHint] = useState<LocationType | undefined>(undefined);
  const [weatherGood, setWeatherGood] = useState(false);

  const [opps, setOpps] = useState<Opportunity[]>([]);
  const [activeIndex, setActiveIndex] = useState(0);
  const [chosen, setChosen] = useState<Opportunity | null>(null);
  const [traceText, setTraceText] = useState("");
  const [savedTraceId, setSavedTraceId] = useState<string | null>(null);
  const [editing, setEditing] = useState(false);
  const [draftText, setDraftText] = useState("");

  const isLateNight = useMemo(() => {
    const h = new Date().getHours();
    return h >= 23 || h < 5;
  }, []);

  const ready = mood != null && energy != null;

  // Pre-select the last mood/energy the user picked, so they aren't re-quizzed.
  // Only fills a still-empty choice; never overrides a fresh selection.
  useEffect(() => {
    if (!hydrated) return;
    if (lastPick.mood) setMood((prev) => prev ?? lastPick.mood);
    if (lastPick.energy) setEnergy((prev) => prev ?? lastPick.energy);
  }, [hydrated, lastPick.mood, lastPick.energy]);

  function handleFind() {
    if (!ready) return;
    rememberPick(mood!, energy!);
    const ctx = {
      ...buildContext({
        mood: mood!,
        energy: energy!,
        freeMinutes: freeTouched ? freeMinutes : undefined,
        locationHint,
        isOutdoorWeatherGood: weatherGood || isGoodOutdoorWeather(weatherKind) || undefined,
        isAtComputer: locationHint === "computer",
      }),
      // fuse the passive senses so the deliberate ask is as keen as the home
      activity,
      ambient,
      deskMinutesToday,
      batteryLow,
    };
    const result = recommend(seeds, ctx, { limit: 3 });
    setOpps(result);
    setActiveIndex(0);
    setOpportunities(result, ctx);
    setStep("list");
  }

  function handleStart(o: Opportunity) {
    setChosen(o);
    setStep("completion");
  }

  function handleSwap() {
    setActiveIndex((i) => (i + 1) % Math.max(opps.length, 1));
  }

  function handleComplete(kind: CompletionKind) {
    const seed = findSeed(seeds, chosen?.seedId);
    if (kind === "skipped") {
      setTraceText(copy.completion.skippedMsg);
      setStep("trace");
      return;
    }
    const trace = buildTrace(seed, kind, chosen?.id);
    addTrace(trace);
    completeFeedback(soundEnabled);
    if (seed && kind === "completed") {
      updateSeed(seed.id, { status: "sleeping" });
    }
    setTraceText(trace.text);
    setSavedTraceId(trace.id);
    setStep("trace");
  }

  function recordRest() {
    const trace = buildRestTrace();
    addTrace(trace);
    setTraceText(trace.text);
    setSavedTraceId(trace.id);
  }

  function saveEditedTrace() {
    const text = draftText.trim();
    if (savedTraceId && text) {
      updateTrace(savedTraceId, { text });
      setTraceText(text);
    }
    setEditing(false);
  }

  // ── Render ────────────────────────────────────────────────
  if (step === "context") {
    return (
      <div className="flex flex-col gap-6">
        {isLateNight && (
          <BreathingCard soft className="whitespace-pre-line text-[14px] leading-relaxed text-[var(--text-secondary)]">
            {copy.lateNight.body}
          </BreathingCard>
        )}
        <section className="flex flex-col gap-3">
          <p className="text-[15px] text-[var(--text)]">{copy.now.moodQuestion}</p>
          <ChipGroup options={moodOptions} value={mood} onChange={setMood} />
        </section>
        <section className="flex flex-col gap-3">
          <p className="text-[15px] text-[var(--text)]">{copy.now.energyQuestion}</p>
          <ChipGroup options={energyOptions} value={energy} onChange={setEnergy} />
        </section>
        <section className="flex flex-col gap-3">
          <p className="text-[15px] text-[var(--text)]">{copy.now.freeQuestion}</p>
          <ChipGroup
            options={freeOptions}
            value={freeTouched ? freeMinutes : (-1 as unknown as number)}
            onChange={(v) => {
              setFreeMinutes(v);
              setFreeTouched(true);
            }}
            isEqual={(a, b) => freeTouched && a === b}
          />
        </section>
        <section className="flex flex-col gap-3">
          <p className="text-[15px] text-[var(--text)]">{copy.now.placeQuestion}</p>
          <ChipGroup
            options={locationOptions}
            value={locationHint}
            onChange={(v) => setLocationHint((cur) => (cur === v ? undefined : v))}
          />
          {(locationHint === "outdoor" || locationHint === "downtown") && (
            <ToggleChip active={weatherGood} onClick={() => setWeatherGood((w) => !w)}>
              {copy.now.weatherLabel}
            </ToggleChip>
          )}
        </section>
        <SoftButton full onClick={handleFind} disabled={!ready}>
          {copy.now.findButton}
        </SoftButton>
      </div>
    );
  }

  if (step === "list") {
    if (opps.length === 0) {
      return (
        <EmptyState
          icon="🍃"
          text={`${copy.now.noneTitle}\n${copy.now.noneBody}`}
          action={{ label: "去种一个新愿望", href: "/add" }}
        />
      );
    }
    const o = opps[activeIndex];
    const seed = findSeed(seeds, o.seedId)!;
    const peeks = opps
      .map((opp, i) => ({ opp, i, seed: findSeed(seeds, opp.seedId) }))
      .filter((p) => p.i !== activeIndex && p.seed);
    return (
      <div className="flex flex-col gap-4">
        <OpportunityCard
          key={o.id}
          opportunity={o}
          seed={seed}
          illustrationStyle={illustrationStyle}
          canSwap={opps.length > 1}
          onStart={() => handleStart(o)}
          onSwap={handleSwap}
          onLater={() => {
            setTraceText("");
            setStep("trace");
          }}
        />
        {peeks.length > 0 && (
          <div className="flex flex-col gap-2 px-1">
            <p className="text-[12px] text-[var(--text-muted)]">或者，现在也可以：</p>
            <div className="flex flex-wrap gap-2">
              {peeks.map((p) => (
                <button
                  key={p.opp.id}
                  onClick={() => setActiveIndex(p.i)}
                  className="rounded-full border border-[var(--border)] bg-[var(--surface)] px-3.5 py-2 text-[13px] text-[var(--text-secondary)] transition-all active:scale-[0.97] hover:bg-[var(--surface-soft)]"
                >
                  {p.seed!.title}
                </button>
              ))}
            </div>
          </div>
        )}
      </div>
    );
  }

  if (step === "completion") {
    return (
      <BreathingCard rise className="flex flex-col gap-5">
        <p className="text-center text-[18px] text-[var(--text)]">{copy.completion.prompt}</p>
        <div className="flex flex-col gap-2">
          <SoftButton full onClick={() => handleComplete("completed")}>
            {copy.completion.done}
          </SoftButton>
          <SoftButton full variant="soft" onClick={() => handleComplete("partial")}>
            {copy.completion.partial}
          </SoftButton>
          <SoftButton full variant="ghost" onClick={() => handleComplete("skipped")}>
            {copy.completion.skipped}
          </SoftButton>
        </div>
      </BreathingCard>
    );
  }

  // step === "trace"
  const canEdit = savedTraceId != null;
  return (
    <div className="flex flex-col gap-5">
      {editing ? (
        <BreathingCard className="flex flex-col gap-3">
          <textarea
            autoFocus
            value={draftText}
            onChange={(e) => setDraftText(e.target.value)}
            placeholder={copy.traces.editPlaceholder}
            rows={4}
            className="w-full resize-none rounded-2xl border border-[var(--border)] bg-[var(--surface-soft)] p-4 text-[16px] leading-relaxed text-[var(--text)] placeholder:text-[var(--text-muted)] focus:outline-none focus:ring-2 focus:ring-[var(--accent-soft)]"
          />
          <div className="flex gap-2">
            <SoftButton full onClick={saveEditedTrace} disabled={!draftText.trim()}>
              {copy.traces.editSave}
            </SoftButton>
            <SoftButton full variant="ghost" onClick={() => setEditing(false)}>
              取消
            </SoftButton>
          </div>
        </BreathingCard>
      ) : (
        <BreathingCard className="tdd-bloom min-h-[160px] items-center justify-center text-center">
          <p className="flex h-full min-h-[120px] items-center justify-center whitespace-pre-line px-2 text-[18px] leading-relaxed text-[var(--text)]">
            {traceText || `${copy.now.later}。\n愿望还在，等下一个契机。`}
          </p>
        </BreathingCard>
      )}
      {!editing && (
        <div className="flex flex-col gap-2">
          {/* The "今天先这样" path saves nothing by default — offer to record
              the choice to stop as its own gentle trace (brief §17). */}
          {!canEdit && traceText === "" && (
            <SoftButton full variant="soft" onClick={recordRest}>
              {copy.now.recordRest}
            </SoftButton>
          )}
          {canEdit && (
            <button
              onClick={() => {
                setDraftText(traceText);
                setEditing(true);
              }}
              className="self-center text-[13px] text-[var(--text-secondary)] underline-offset-4 hover:underline"
            >
              {copy.traces.edit}
            </button>
          )}
          <SoftButton full onClick={() => router.push("/")}>
            回到今天
          </SoftButton>
          <SoftButton full variant="ghost" onClick={() => router.push("/traces")}>
            看看今日痕迹
          </SoftButton>
        </div>
      )}
    </div>
  );
}
