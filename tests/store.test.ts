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

describe("store — seed lifecycle (detail page actions)", () => {
  it("edits a seed's title and minimum action and persists", () => {
    const seed = materializeSeed(mockSeeds[0]);
    useStore.getState().addSeed(seed);

    useStore.getState().updateSeed(seed.id, { title: "新标题", minimumAction: "做最小的一步" });

    const updated = useStore.getState().seeds.find((s) => s.id === seed.id);
    expect(updated?.title).toBe("新标题");
    expect(updated?.minimumAction).toBe("做最小的一步");
    expect(storage.loadSeeds().find((s) => s.id === seed.id)?.title).toBe("新标题");
  });

  it("moves a seed through sleep → wake → archive → restore", () => {
    const seed = materializeSeed(mockSeeds[2]);
    useStore.getState().addSeed(seed);
    const status = () => useStore.getState().seeds.find((s) => s.id === seed.id)?.status;

    useStore.getState().setSeedStatus(seed.id, "sleeping");
    expect(status()).toBe("sleeping");
    useStore.getState().setSeedStatus(seed.id, "active");
    expect(status()).toBe("active");
    useStore.getState().setSeedStatus(seed.id, "archived");
    expect(status()).toBe("archived");
    useStore.getState().setSeedStatus(seed.id, "active");
    expect(status()).toBe("active");
  });
});
