"use client";

import Link from "next/link";
import { useStore } from "@/lib/store";
import SeedCard from "./SeedCard";
import EmptyState from "@/components/design/EmptyState";
import { copy } from "@/lib/copy";

export default function SeedGarden() {
  const seeds = useStore((s) => s.seeds);
  const hydrated = useStore((s) => s.hydrated);
  const illustrationStyle = useStore((s) => s.settings.illustrationStyle);

  if (!hydrated) return null;

  const visible = seeds.filter((s) => s.status !== "archived");

  if (visible.length === 0) {
    return (
      <EmptyState
        icon="🌱"
        text={copy.garden.empty}
        action={{ label: "种下第一个愿望", href: "/add" }}
      />
    );
  }

  return (
    <div className="flex flex-col gap-3">
      {visible.map((seed) => (
        <Link key={seed.id} href={`/seeds/${seed.id}`} className="block active:scale-[0.99] transition-transform">
          <SeedCard seed={seed} illustrationStyle={illustrationStyle} />
        </Link>
      ))}
    </div>
  );
}
