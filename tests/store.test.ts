import { describe, it, expect, beforeEach } from "vitest";
import { useStore } from "@/lib/store";
import { buildTrace } from "@/lib/traceGenerator";
import { materializeSeed, mockSeeds } from "@/lib/mockSeeds";
import { storage } from "@/lib/storage";

beforeEach(() => {
  window.localStorage.clear();
  // reset transient + persisted store slices
  useStore.setState({ traces: [], seeds: [], hydrated: true });
});

describe("store.updateTrace", () => {
  it("rewrites a trace's text and persists it", () => {
    const seed = materializeSeed(mockSeeds[3]); // 吃一顿热饭
    const trace = buildTrace(seed, "completed");
    useStore.getState().addTrace(trace);

    useStore.getState().updateTrace(trace.id, { text: "今天没有消失，因为我自己写下了这句。" });

    const updated = useStore.getState().traces.find((t) => t.id === trace.id);
    expect(updated?.text).toBe("今天没有消失，因为我自己写下了这句。");
    // persisted, not just in memory
    expect(storage.loadTraces().find((t) => t.id === trace.id)?.text).toBe(
      "今天没有消失，因为我自己写下了这句。"
    );
  });

  it("leaves other traces untouched", () => {
    const a = buildTrace(materializeSeed(mockSeeds[0]), "completed");
    const b = buildTrace(materializeSeed(mockSeeds[1]), "partial");
    useStore.getState().addTrace(a);
    useStore.getState().addTrace(b);

    useStore.getState().updateTrace(a.id, { text: "changed" });

    expect(useStore.getState().traces.find((t) => t.id === b.id)?.text).toBe(b.text);
  });
});
