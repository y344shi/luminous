"use client";

import { useStore } from "@/lib/store";
import { copy } from "@core/copy";
import BreathingCard from "@/components/design/BreathingCard";

export default function TodayTracePreview() {
  const hydrated = useStore((s) => s.hydrated);
  const tracesForToday = useStore((s) => s.tracesForToday);

  const today = hydrated ? tracesForToday() : [];

  return (
    <section className="flex flex-col gap-2">
      <p className="px-1 text-[13px] font-medium text-[var(--text-muted)]">
        {copy.home.traceHeading}
      </p>
      {today.length === 0 ? (
        <BreathingCard soft>
          <p className="text-[14px] text-[var(--text-secondary)]">{copy.home.traceEmpty}</p>
        </BreathingCard>
      ) : (
        <div className="flex flex-col gap-2">
          {today.slice(0, 3).map((t) => (
            <BreathingCard key={t.id} soft>
              <p className="text-[14px] leading-relaxed text-[var(--text)]">{t.text}</p>
            </BreathingCard>
          ))}
        </div>
      )}
    </section>
  );
}
