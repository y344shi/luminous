"use client";

import { create } from "zustand";
import type {
  Seed,
  DailyTrace,
  Settings,
  ThemeName,
  Opportunity,
  ContextSnapshot,
  SeedStatus,
  Mood,
  Energy,
} from "./types";
import { storage, defaultSettings, type LastPick } from "./storage";
import type { Coords } from "@core/geo";
import { seedMockGarden } from "./mockSeeds";
import { localDateKey } from "@core/utils";

type Store = {
  hydrated: boolean;
  seeds: Seed[];
  traces: DailyTrace[];
  settings: Settings;
  samplesPlanted: boolean;
  lastPick: LastPick;
  introSeen: boolean;
  homeLocation: Coords | null;

  // transient (not persisted)
  lastContext: ContextSnapshot | null;
  opportunities: Opportunity[];

  hydrate: () => void;

  addSeed: (seed: Seed) => void;
  updateSeed: (id: string, patch: Partial<Seed>) => void;
  setSeedStatus: (id: string, status: SeedStatus) => void;

  addTrace: (trace: DailyTrace) => void;
  updateTrace: (id: string, patch: Partial<DailyTrace>) => void;
  removeTrace: (id: string) => void;
  tracesForToday: () => DailyTrace[];

  setOpportunities: (opps: Opportunity[], ctx: ContextSnapshot) => void;
  clearOpportunities: () => void;
  rememberPick: (mood: Mood, energy: Energy) => void;

  setTheme: (theme: ThemeName) => void;
  updateSettings: (patch: Partial<Settings>) => void;
  dismissSamplesNote: () => void;
  dismissIntro: () => void;
  setHomeLocation: (c: Coords | null) => void;
  resetAll: () => void;
};

export const useStore = create<Store>((set, get) => ({
  hydrated: false,
  seeds: [],
  traces: [],
  settings: defaultSettings,
  samplesPlanted: false,
  lastPick: {},
  introSeen: false,
  homeLocation: null,
  lastContext: null,
  opportunities: [],

  hydrate: () => {
    if (get().hydrated) return;
    let seeds = storage.loadSeeds();
    const settings = storage.loadSettings();
    const theme = storage.loadTheme();
    if (theme) settings.theme = theme;

    // First run: plant a small mock garden so the app never feels empty/dead.
    let samplesPlanted = storage.loadSamplesPlanted();
    if (seeds.length === 0 && storage.loadTraces().length === 0) {
      seeds = seedMockGarden();
      storage.saveSeeds(seeds);
      samplesPlanted = true;
      storage.saveSamplesPlanted(true);
    }

    set({
      hydrated: true,
      seeds,
      traces: storage.loadTraces(),
      settings,
      samplesPlanted,
      lastPick: storage.loadLastPick(),
      introSeen: storage.loadIntroSeen(),
      homeLocation: storage.loadHome(),
    });
  },

  addSeed: (seed) => {
    const seeds = [seed, ...get().seeds];
    set({ seeds });
    storage.saveSeeds(seeds);
    // The user planted their own wish — it's their garden now.
    if (get().samplesPlanted) {
      set({ samplesPlanted: false });
      storage.saveSamplesPlanted(false);
    }
  },

  updateSeed: (id, patch) => {
    const seeds = get().seeds.map((s) =>
      s.id === id ? { ...s, ...patch, updatedAt: new Date().toISOString() } : s
    );
    set({ seeds });
    storage.saveSeeds(seeds);
  },

  setSeedStatus: (id, status) => {
    get().updateSeed(id, { status });
  },

  addTrace: (trace) => {
    // Keep the journal bounded so localStorage can't grow without limit.
    const MAX_TRACES = 500;
    let traces = [trace, ...get().traces];
    if (traces.length > MAX_TRACES) traces = traces.slice(0, MAX_TRACES);
    set({ traces });
    storage.saveTraces(traces);
  },

  updateTrace: (id, patch) => {
    const traces = get().traces.map((t) => (t.id === id ? { ...t, ...patch } : t));
    set({ traces });
    storage.saveTraces(traces);
  },

  removeTrace: (id) => {
    const traces = get().traces.filter((t) => t.id !== id);
    set({ traces });
    storage.saveTraces(traces);
  },

  tracesForToday: () => {
    const today = localDateKey();
    return get().traces.filter((t) => t.date === today);
  },

  setOpportunities: (opps, ctx) => set({ opportunities: opps, lastContext: ctx }),
  clearOpportunities: () => set({ opportunities: [], lastContext: null }),

  rememberPick: (mood, energy) => {
    const lastPick = { mood, energy };
    set({ lastPick });
    storage.saveLastPick(lastPick);
  },

  setTheme: (theme) => {
    const settings = { ...get().settings, theme };
    set({ settings });
    storage.saveTheme(theme);
    storage.saveSettings(settings);
  },

  updateSettings: (patch) => {
    const settings = { ...get().settings, ...patch };
    set({ settings });
    storage.saveSettings(settings);
    if (patch.theme) storage.saveTheme(patch.theme);
  },

  dismissSamplesNote: () => {
    set({ samplesPlanted: false });
    storage.saveSamplesPlanted(false);
  },

  dismissIntro: () => {
    set({ introSeen: true });
    storage.saveIntroSeen(true);
  },

  setHomeLocation: (c) => {
    set({ homeLocation: c });
    storage.saveHome(c);
  },

  resetAll: () => {
    storage.clearAll();
    const seeds = seedMockGarden();
    storage.saveSeeds(seeds);
    storage.saveSamplesPlanted(true);
    set({
      seeds,
      traces: [],
      settings: defaultSettings,
      samplesPlanted: true,
      lastPick: {},
      introSeen: false,
      homeLocation: null,
      opportunities: [],
      lastContext: null,
    });
  },
}));

export function findSeed(seeds: Seed[], id?: string): Seed | undefined {
  if (!id) return undefined;
  return seeds.find((s) => s.id === id);
}
