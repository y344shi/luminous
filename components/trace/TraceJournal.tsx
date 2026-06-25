"use client";

import { useState } from "react";
import { useStore } from "@/lib/store";
import TraceCard from "./TraceCard";
import EmptyState from "@/components/design/EmptyState";
import ConfirmSheet from "@/components/design/ConfirmSheet";
import { copy } from "@/lib/copy";
import { friendlyDate } from "@/lib/utils";
import type { DailyTrace } from "@/lib/types";

function groupByDate(traces: DailyTrace[]): [string, DailyTrace[]][] {
  const map = new Map<string, DailyTrace[]>();
  for (const t of traces) {
    const arr = map.get(t.date) ?? [];
    arr.push(t);
    map.set(t.date, arr);
  }
  return Array.from(map.entries()).sort((a, b) => (a[0] < b[0] ? 1 : -1));
}

export default function TraceJournal() {
  const traces = useStore((s) => s.traces);
  const hydrated = useStore((s) => s.hydrated);
  const removeTrace = useStore((s) => s.removeTrace);
  const [pendingDelete, setPendingDelete] = useState<string | null>(null);

  if (!hydrated) return null;
  if (traces.length === 0)
    return (
      <EmptyState
        icon="🪵"
        text={copy.traces.empty}
        action={{ label: "现在别消失", href: "/now" }}
      />
    );

  const groups = groupByDate(traces);

  return (
    <div className="flex flex-col gap-6">
      {groups.map(([date, items]) => (
        <section key={date} className="flex flex-col gap-3">
          <h2 className="px-1 text-[13px] font-medium text-[var(--text-muted)]">
            {friendlyDate(date)}
          </h2>
          {items.map((t) => (
            <TraceCard key={t.id} trace={t} onRequestDelete={() => setPendingDelete(t.id)} />
          ))}
        </section>
      ))}

      <ConfirmSheet
        open={pendingDelete !== null}
        title={copy.traces.deleteTitle}
        body={copy.traces.deleteBody}
        confirmLabel={copy.traces.deleteYes}
        cancelLabel={copy.traces.deleteNo}
        onConfirm={() => {
          if (pendingDelete) removeTrace(pendingDelete);
          setPendingDelete(null);
        }}
        onCancel={() => setPendingDelete(null)}
      />
    </div>
  );
}
