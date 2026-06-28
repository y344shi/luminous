"use client";

import Link from "next/link";
import { useStore } from "@/lib/store";
import { copy } from "@core/copy";
import { IllustrationArt } from "@/components/home/shared/illustrationPacks";
import { illustrationCategory } from "@core/illustration";
import BreathingCard from "@/components/design/BreathingCard";

export default function RecentSeeds() {
  const hydrated = useStore((s) => s.hydrated);
  const seeds = useStore((s) => s.seeds);
  const illustrationStyle = useStore((s) => s.settings.illustrationStyle);

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
              <span className="flex h-7 w-7 shrink-0 items-center justify-center overflow-hidden rounded-md bg-[#f1ece2]">
                <IllustrationArt style={illustrationStyle} category={illustrationCategory(s.categories, s.id)} className="h-full w-full" />
              </span>
              <span className="text-[15px] text-[var(--text)]">{s.title}</span>
            </BreathingCard>
          ))}
        </div>
      )}
    </section>
  );
}
