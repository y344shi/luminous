import type { DailyTrace } from "@/lib/types";
import { categoryMeta } from "@/lib/categoryMeta";
import BreathingCard from "@/components/design/BreathingCard";

export default function TraceCard({ trace }: { trace: DailyTrace }) {
  const meta = trace.category ? categoryMeta[trace.category] : undefined;
  return (
    <BreathingCard soft className="flex items-start gap-3">
      <span className="text-lg" aria-hidden>
        {meta?.emoji ?? "·"}
      </span>
      <p className="text-[15px] leading-relaxed text-[var(--text)]">{trace.text}</p>
    </BreathingCard>
  );
}
