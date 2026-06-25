"use client";

import Link from "next/link";
import { useStore } from "@/lib/store";
import { copy } from "@/lib/copy";
import { categoryMeta } from "@/lib/categoryMeta";
import BreathingCard from "@/components/design/BreathingCard";

export default function RecentSeeds() {
  const hydrated = useStore((s) => s.hydrated);
  const seeds = useStore((s) => s.seeds);

  if (!hydrated) return null;
  const recent = seeds.filter((s) => s.status === "active" || s.status === "sleeping").slice(0, 3);

  return (
    <section className="flex flex-col gap-2">
      <div className="flex items-center justify-between px-1">
        <p className="text-[13px] font-medium text-[var(--text-muted)]">
          {copy.home.seedsHeading}
        </p>
        <Link href="/seeds" className="text-[12px] text-[var(--text-secondary)]">
          全部
        </Link>
      </div>
      {recent.length === 0 ? (
        <BreathingCard soft>
          <p className="text-[14px] text-[var(--text-secondary)]">{copy.home.seedsEmpty}</p>
        </BreathingCard>
      ) : (
        <div className="flex flex-col gap-2">
          {recent.map((s) => (
            <BreathingCard key={s.id} soft className="flex items-center gap-3 py-3">
              <span aria-hidden>{categoryMeta[s.categories[0]]?.emoji}</span>
              <span className="text-[15px] text-[var(--text)]">{s.title}</span>
            </BreathingCard>
          ))}
        </div>
      )}
    </section>
  );
}
