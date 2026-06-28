import type { DailyTrace } from "@core/types";
import { categoryMeta } from "@core/categoryMeta";
import { copy } from "@core/copy";
import BreathingCard from "@/components/design/BreathingCard";

export default function TraceCard({
  trace,
  onRequestDelete,
}: {
  trace: DailyTrace;
  /** When provided, shows a subtle "擦掉" affordance. */
  onRequestDelete?: () => void;
}) {
  const meta = trace.category ? categoryMeta[trace.category] : undefined;
  return (
    <BreathingCard soft className="flex items-start gap-3">
      <span className="text-lg" aria-hidden>
        {meta?.emoji ?? "·"}
      </span>
      <p className="flex-1 text-[15px] leading-relaxed text-[var(--text)]">{trace.text}</p>
      {onRequestDelete && (
        <button
          onClick={onRequestDelete}
          aria-label={copy.traces.deleteAria}
          className="-mr-1 -mt-1 shrink-0 rounded-full px-2 py-1 text-[15px] leading-none text-[var(--text-muted)] opacity-60 transition-opacity hover:opacity-100"
        >
          ×
        </button>
      )}
    </BreathingCard>
  );
}
