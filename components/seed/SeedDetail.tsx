"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useStore } from "@/lib/store";
import { copy } from "@/lib/copy";
import { categoryMeta, energyLabel, durationLabel } from "@/lib/categoryMeta";
import type { SeedStatus } from "@/lib/types";
import BreathingCard from "@/components/design/BreathingCard";
import SoftButton from "@/components/design/SoftButton";
import EmptyState from "@/components/design/EmptyState";
import { IllustrationArt } from "@/components/home/shared/illustrationPacks";
import { illustrationCategory } from "@/lib/illustration";

const statusText: Record<SeedStatus, string> = {
  active: copy.seedDetail.statusActive,
  sleeping: copy.seedDetail.statusSleeping,
  completed: "曾经做到过",
  archived: copy.seedDetail.statusArchived,
};

export default function SeedDetail({ id }: { id: string }) {
  const router = useRouter();
  const hydrated = useStore((s) => s.hydrated);
  const seed = useStore((s) => s.seeds.find((x) => x.id === id));
  const updateSeed = useStore((s) => s.updateSeed);
  const setSeedStatus = useStore((s) => s.setSeedStatus);
  const illustrationStyle = useStore((s) => s.settings.illustrationStyle);

  const [title, setTitle] = useState(seed?.title ?? "");
  const [minimumAction, setMinimumAction] = useState(seed?.minimumAction ?? "");
  const [savedFlash, setSavedFlash] = useState(false);

  if (!hydrated) return null;

  if (!seed) {
    return (
      <EmptyState
        icon="🍃"
        text={copy.seedDetail.notFound}
        action={{ label: copy.seedDetail.back.replace("← ", ""), href: "/seeds" }}
      />
    );
  }

  const dirty = title.trim() !== seed.title || minimumAction.trim() !== seed.minimumAction;

  function save() {
    if (!seed) return;
    updateSeed(seed.id, {
      title: title.trim() || seed.title,
      minimumAction: minimumAction.trim() || seed.minimumAction,
    });
    setSavedFlash(true);
    setTimeout(() => setSavedFlash(false), 1500);
  }

  function changeStatus(status: SeedStatus, leave = false) {
    if (!seed) return;
    setSeedStatus(seed.id, status);
    if (leave) router.push("/seeds");
  }

  const cat = illustrationCategory(seed.categories, seed.id);

  return (
    <div className="flex flex-col gap-5">
      <Link href="/seeds" className="text-[14px] text-[var(--text-secondary)]">
        {copy.seedDetail.back}
      </Link>

      <BreathingCard className="flex flex-col gap-4">
        <div className="flex items-center justify-between gap-3">
          <span className="flex h-11 w-11 shrink-0 items-center justify-center overflow-hidden rounded-xl bg-[#f1ece2]">
            <IllustrationArt style={illustrationStyle} category={cat} className="h-full w-full" />
          </span>
          <span className="rounded-full bg-[var(--surface-soft)] px-3 py-1 text-[12px] text-[var(--text-muted)]">
            {statusText[seed.status]}
          </span>
        </div>

        <div className="flex flex-col gap-2">
          <label htmlFor="seed-title" className="text-[12px] text-[var(--text-muted)]">
            {copy.seedDetail.titleLabel}
          </label>
          <input
            id="seed-title"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="w-full rounded-2xl border border-[var(--border)] bg-[var(--surface-soft)] px-4 py-3 text-[17px] text-[var(--text)] focus:outline-none focus:ring-2 focus:ring-[var(--accent-soft)]"
          />
        </div>

        <div className="flex flex-col gap-2">
          <label htmlFor="seed-min" className="text-[12px] text-[var(--text-muted)]">
            {copy.seedDetail.minLabel}
          </label>
          <textarea
            id="seed-min"
            value={minimumAction}
            onChange={(e) => setMinimumAction(e.target.value)}
            rows={3}
            className="w-full resize-none rounded-2xl border border-[var(--border)] bg-[var(--surface-soft)] px-4 py-3 text-[15px] leading-relaxed text-[var(--text)] focus:outline-none focus:ring-2 focus:ring-[var(--accent-soft)]"
          />
        </div>

        <div className="flex flex-wrap gap-2">
          {seed.categories.map((c) => (
            <span key={c} className="rounded-full bg-[var(--accent-soft)] px-2.5 py-1 text-[11px] text-[var(--text-secondary)]">
              {categoryMeta[c]?.label}
            </span>
          ))}
          <span className="rounded-full bg-[var(--surface-soft)] px-2.5 py-1 text-[11px] text-[var(--text-muted)]">
            {durationLabel(seed.estimatedDurationMin)}
          </span>
          <span className="rounded-full bg-[var(--surface-soft)] px-2.5 py-1 text-[11px] text-[var(--text-muted)]">
            {energyLabel[seed.energyRequired]}
          </span>
        </div>
      </BreathingCard>

      <div className="flex flex-col gap-2">
        <SoftButton full onClick={save} disabled={!dirty}>
          {savedFlash ? copy.seedDetail.saved : copy.seedDetail.save}
        </SoftButton>

        <div className="flex gap-2">
          {seed.status === "active" && (
            <SoftButton variant="soft" full onClick={() => changeStatus("sleeping")}>
              {copy.seedDetail.sleep}
            </SoftButton>
          )}
          {seed.status === "sleeping" && (
            <SoftButton variant="soft" full onClick={() => changeStatus("active")}>
              {copy.seedDetail.wake}
            </SoftButton>
          )}
          {seed.status === "archived" ? (
            <SoftButton variant="soft" full onClick={() => changeStatus("active", true)}>
              {copy.seedDetail.restore}
            </SoftButton>
          ) : (
            <SoftButton variant="ghost" full onClick={() => changeStatus("archived", true)}>
              {copy.seedDetail.archive}
            </SoftButton>
          )}
        </div>
      </div>
    </div>
  );
}
