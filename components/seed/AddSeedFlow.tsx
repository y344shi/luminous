"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { draftToSeed, type SeedDraft } from "@/lib/seedParser";
import { parseSeed } from "@/lib/aiParser";
import { useStore } from "@/lib/store";
import { copy } from "@/lib/copy";
import { categoryMeta, durationLabel } from "@/lib/categoryMeta";
import BreathingCard from "@/components/design/BreathingCard";
import SoftButton from "@/components/design/SoftButton";

const semanticTimeLabel: Record<string, string> = {
  morning: "早上",
  lunch: "中午",
  afternoon: "下午",
  after_work: "傍晚",
  evening: "晚上",
  late_night: "深夜",
  weekend: "周末",
  transit: "路上",
};

export default function AddSeedFlow() {
  const router = useRouter();
  const addSeed = useStore((s) => s.addSeed);
  const aiMode = useStore((s) => s.settings.aiMode);
  const [text, setText] = useState("");
  const [draft, setDraft] = useState<SeedDraft | null>(null);
  const [saved, setSaved] = useState(false);
  const [catching, setCatching] = useState(false);

  async function handleCatch() {
    if (!text.trim() || catching) return;
    setCatching(true);
    try {
      setDraft(await parseSeed(text, aiMode));
    } finally {
      setCatching(false);
    }
  }

  function handleSave() {
    if (!draft) return;
    addSeed(draftToSeed(draft));
    setSaved(true);
    setTimeout(() => router.push("/seeds"), 700);
  }

  function handleEditAgain() {
    setDraft(null);
  }

  if (saved) {
    return (
      <BreathingCard rise className="text-center">
        <p className="py-6 text-[15px] text-[var(--text-secondary)]">
          已经帮你接住了。
          <br />
          它会在合适的时机回来。
        </p>
      </BreathingCard>
    );
  }

  if (draft) {
    return (
      <div className="flex flex-col gap-4 tdd-rise">
        <p className="text-[14px] text-[var(--text-secondary)]">{copy.add.caught}</p>
        <BreathingCard className="flex flex-col gap-4">
          <div className="flex items-center gap-2">
            <span className="text-lg">{categoryMeta[draft.categories[0]]?.emoji}</span>
            <h2 className="text-[18px] font-medium">{draft.title}</h2>
          </div>

          <div>
            <p className="text-[12px] text-[var(--text-muted)]">{copy.add.minLabel}</p>
            <p className="mt-1 text-[15px] text-[var(--text)]">{draft.minimumAction}</p>
          </div>

          <div>
            <p className="text-[12px] text-[var(--text-muted)]">{copy.add.fitLabel}</p>
            <p className="mt-1 text-[14px] text-[var(--text-secondary)]">
              {draft.preferredTimes.map((t) => semanticTimeLabel[t] ?? t).join("、")} ·{" "}
              {durationLabel(draft.estimatedDurationMin)}
            </p>
          </div>
        </BreathingCard>

        <div className="flex flex-col gap-2">
          <SoftButton full onClick={handleSave}>
            {copy.add.save}
          </SoftButton>
          <SoftButton full variant="ghost" onClick={handleEditAgain}>
            {copy.add.edit}
          </SoftButton>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <textarea
        autoFocus
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder={copy.add.placeholder}
        rows={5}
        className="w-full resize-none rounded-[24px] border border-[var(--border)] bg-[var(--surface)] p-5 text-[16px] leading-relaxed text-[var(--text)] placeholder:text-[var(--text-muted)] shadow-[var(--shadow-card)] focus:outline-none focus:ring-2 focus:ring-[var(--accent-soft)]"
      />
      <SoftButton full onClick={handleCatch} disabled={!text.trim() || catching}>
        {catching ? "正在接住……" : "把这个愿望先接住"}
      </SoftButton>
    </div>
  );
}
