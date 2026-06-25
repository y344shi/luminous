"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import type { Mood, Energy, Opportunity } from "@/lib/types";
import { useStore, findSeed } from "@/lib/store";
import { buildContext } from "@/lib/context";
import { recommend } from "@/lib/scoring";
import { buildTrace, type CompletionKind } from "@/lib/traceGenerator";
import { copy } from "@/lib/copy";
import BreathingCard from "@/components/design/BreathingCard";
import SoftButton from "@/components/design/SoftButton";
import EmptyState from "@/components/design/EmptyState";
import OpportunityCard from "./OpportunityCard";
import {
  ChipGroup,
  moodOptions,
  energyOptions,
  freeOptions,
} from "@/components/context/Pickers";

type Step = "context" | "list" | "completion" | "trace";

export default function NowFlow() {
  const router = useRouter();
  const seeds = useStore((s) => s.seeds);
  const setOpportunities = useStore((s) => s.setOpportunities);
  const addTrace = useStore((s) => s.addTrace);
  const updateSeed = useStore((s) => s.updateSeed);

  const [step, setStep] = useState<Step>("context");
  const [mood, setMood] = useState<Mood>();
  const [energy, setEnergy] = useState<Energy>();
  const [freeMinutes, setFreeMinutes] = useState<number | undefined>(undefined);
  const [freeTouched, setFreeTouched] = useState(false);

  const [opps, setOpps] = useState<Opportunity[]>([]);
  const [activeIndex, setActiveIndex] = useState(0);
  const [chosen, setChosen] = useState<Opportunity | null>(null);
  const [traceText, setTraceText] = useState("");

  const isLateNight = useMemo(() => {
    const h = new Date().getHours();
    return h >= 23 || h < 5;
  }, []);

  const ready = mood != null && energy != null;

  function handleFind() {
    if (!ready) return;
    const ctx = buildContext({
      mood: mood!,
      energy: energy!,
      freeMinutes: freeTouched ? freeMinutes : undefined,
      isAtComputer: true,
    });
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
    if (seed && kind === "completed") {
      updateSeed(seed.id, { status: "sleeping" });
    }
    setTraceText(trace.text);
    setStep("trace");
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
        <SoftButton full onClick={handleFind} disabled={!ready}>
          {copy.now.findButton}
        </SoftButton>
      </div>
    );
  }

  if (step === "list") {
    if (opps.length === 0) {
      return (
        <div className="flex flex-col gap-4">
          <EmptyState text={`${copy.now.noneTitle}\n${copy.now.noneBody}`} />
          <SoftButton full variant="ghost" onClick={() => router.push("/add")}>
            去种一个新愿望
          </SoftButton>
        </div>
      );
    }
    const o = opps[activeIndex];
    const seed = findSeed(seeds, o.seedId)!;
    return (
      <OpportunityCard
        key={o.id}
        opportunity={o}
        seed={seed}
        canSwap={opps.length > 1}
        onStart={() => handleStart(o)}
        onSwap={handleSwap}
        onLater={() => {
          setTraceText("");
          setStep("trace");
        }}
      />
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
  return (
    <div className="flex flex-col gap-5">
      <BreathingCard rise className="min-h-[160px] items-center justify-center text-center">
        <p className="flex h-full min-h-[120px] items-center justify-center whitespace-pre-line px-2 text-[18px] leading-relaxed text-[var(--text)]">
          {traceText || `${copy.now.later}。\n愿望还在，等下一个契机。`}
        </p>
      </BreathingCard>
      <div className="flex flex-col gap-2">
        <SoftButton full onClick={() => router.push("/")}>
          回到今天
        </SoftButton>
        <SoftButton full variant="ghost" onClick={() => router.push("/traces")}>
          看看今日痕迹
        </SoftButton>
      </div>
    </div>
  );
}
