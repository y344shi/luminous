import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, cleanup } from "@testing-library/react";
import { copy, forbiddenWords } from "@core/copy";
import { useStore } from "@/lib/store";
import { seedMockGarden } from "@core/mockSeeds";

// Components that touch next/navigation need it stubbed in jsdom.
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn() }),
  usePathname: () => "/",
}));

import BubbleField from "@/components/home/shared/BubbleField";
import SeedGarden from "@/components/seed/SeedGarden";
import TraceJournal from "@/components/trace/TraceJournal";
import SettingsPanel from "@/components/settings/SettingsPanel";
import NowFlow from "@/components/opportunity/NowFlow";
import AddSeedFlow from "@/components/seed/AddSeedFlow";

/** Recursively gather every string leaf in the copy object. */
function collectStrings(obj: unknown, acc: string[] = []): string[] {
  if (typeof obj === "string") acc.push(obj);
  else if (Array.isArray(obj)) obj.forEach((v) => collectStrings(v, acc));
  else if (obj && typeof obj === "object")
    Object.values(obj as Record<string, unknown>).forEach((v) => collectStrings(v, acc));
  return acc;
}

function findForbidden(text: string): string[] {
  const lower = text.toLowerCase();
  return forbiddenWords.filter((w) => lower.includes(w.toLowerCase()));
}

beforeEach(() => {
  window.localStorage.clear();
  useStore.setState({ seeds: seedMockGarden(), traces: [], hydrated: true });
});

describe("copy-lint — tone never drifts into todo-app language", () => {
  it("the copy dictionary contains no forbidden vocabulary", () => {
    const strings = collectStrings(copy);
    expect(strings.length).toBeGreaterThan(20); // sanity: we actually scanned copy
    const offenders = strings.flatMap((s) => findForbidden(s).map((w) => `${w} in "${s}"`));
    expect(offenders).toEqual([]);
  });

  it.each([
    ["Home field", () => <BubbleField />],
    ["Seed garden", () => <SeedGarden />],
    ["Trace journal", () => <TraceJournal />],
    ["Settings", () => <SettingsPanel />],
    ["Now flow", () => <NowFlow />],
    ["Add seed", () => <AddSeedFlow />],
  ])("rendered screen %s shows no forbidden words", (_name, El) => {
    render(<El />);
    const text = document.body.textContent ?? "";
    expect(findForbidden(text)).toEqual([]);
    cleanup();
  });
});
