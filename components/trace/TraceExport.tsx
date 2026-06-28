"use client";

import { useState } from "react";
import { useStore } from "@/lib/store";
import { copy } from "@core/copy";
import { formatTracesForExport } from "@/lib/exportTraces";
import SoftButton from "@/components/design/SoftButton";

type Status = "idle" | "done" | "failed";

/**
 * Lets the user keep their traces — copy the whole journal as plain text.
 * The traces are theirs; the only other data action is destructive reset.
 */
export default function TraceExport() {
  const hydrated = useStore((s) => s.hydrated);
  const traces = useStore((s) => s.traces);
  const [status, setStatus] = useState<Status>("idle");

  if (!hydrated || traces.length === 0) return null;

  async function handleExport() {
    const text = formatTracesForExport(traces);
    try {
      if (typeof navigator !== "undefined" && navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(text);
        setStatus("done");
      } else {
        throw new Error("clipboard unavailable");
      }
    } catch {
      setStatus("failed");
    }
    setTimeout(() => setStatus("idle"), 2500);
  }

  return (
    <div className="flex flex-col items-center gap-2 pt-2">
      <SoftButton variant="soft" onClick={handleExport}>
        {status === "done" ? copy.traces.exported : copy.traces.export}
      </SoftButton>
      {status === "failed" && (
        <p className="px-4 text-center text-[12px] text-[var(--text-muted)]">
          {copy.traces.exportFailed}
        </p>
      )}
    </div>
  );
}
