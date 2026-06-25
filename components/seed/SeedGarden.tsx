"use client";

import { useStore } from "@/lib/store";
import SeedCard from "./SeedCard";
import EmptyState from "@/components/design/EmptyState";
import { copy } from "@/lib/copy";

export default function SeedGarden() {
  const seeds = useStore((s) => s.seeds);
  const hydrated = useStore((s) => s.hydrated);

  if (!hydrated) return null;

  const visible = seeds.filter((s) => s.status !== "archived");

  if (visible.length === 0) {
    return <EmptyState text={copy.garden.empty} />;
  }

  return (
    <div className="flex flex-col gap-3">
      {visible.map((seed) => (
        <SeedCard key={seed.id} seed={seed} />
      ))}
    </div>
  );
}
