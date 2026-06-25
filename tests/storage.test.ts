import { describe, it, expect, beforeEach } from "vitest";
import { storage, STORAGE_KEYS, defaultSettings } from "@/lib/storage";
import { seedMockGarden } from "@/lib/mockSeeds";

beforeEach(() => {
  window.localStorage.clear();
});

describe("storage", () => {
  it("persists and reloads seeds", () => {
    const seeds = seedMockGarden();
    storage.saveSeeds(seeds);
    const loaded = storage.loadSeeds();
    expect(loaded.length).toBe(seeds.length);
    expect(loaded[0].id).toBe(seeds[0].id);
  });

  it("returns empty array when nothing stored", () => {
    expect(storage.loadSeeds()).toEqual([]);
    expect(storage.loadTraces()).toEqual([]);
  });

  it("merges partial settings with defaults", () => {
    window.localStorage.setItem(STORAGE_KEYS.settings, JSON.stringify({ maxRemindersPerDay: 1 }));
    const s = storage.loadSettings();
    expect(s.maxRemindersPerDay).toBe(1);
    expect(s.theme).toBe(defaultSettings.theme);
  });

  it("stores selected theme", () => {
    storage.saveTheme("soft_ritual");
    expect(storage.loadTheme()).toBe("soft_ritual");
  });

  it("clearAll wipes everything", () => {
    storage.saveSeeds(seedMockGarden());
    storage.saveTheme("dusk_garden");
    storage.clearAll();
    expect(storage.loadSeeds()).toEqual([]);
    expect(storage.loadTheme()).toBeNull();
  });

  it("persists the late-night theme-offer dismissal token", () => {
    expect(storage.loadRitualOfferDismissed()).toBeNull();
    storage.saveRitualOfferDismissed("2026-06-25");
    expect(storage.loadRitualOfferDismissed()).toBe("2026-06-25");
    storage.clearAll();
    expect(storage.loadRitualOfferDismissed()).toBeNull();
  });

  it("survives corrupt JSON gracefully", () => {
    window.localStorage.setItem(STORAGE_KEYS.seeds, "{not valid json");
    expect(storage.loadSeeds()).toEqual([]);
  });
});
