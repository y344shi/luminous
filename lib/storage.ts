import type { Seed, DailyTrace, Settings, ThemeName } from "./types";

export const STORAGE_KEYS = {
  seeds: "tdd.seeds",
  traces: "tdd.traces",
  theme: "tdd.theme",
  settings: "tdd.settings",
  ritualOffer: "tdd.ritualOfferDismissed",
} as const;

export const defaultSettings: Settings = {
  theme: "warm_paper",
  aiMode: "mock",
  quietHoursStart: 23,
  quietHoursEnd: 8,
  maxRemindersPerDay: 3,
};

function isBrowser(): boolean {
  return typeof window !== "undefined" && typeof window.localStorage !== "undefined";
}

function read<T>(key: string, fallback: T): T {
  if (!isBrowser()) return fallback;
  try {
    const raw = window.localStorage.getItem(key);
    if (raw == null) return fallback;
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

function write<T>(key: string, value: T): void {
  if (!isBrowser()) return;
  try {
    window.localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // storage full / disabled — fail soft, the app must stay alive
  }
}

export const storage = {
  loadSeeds(): Seed[] {
    return read<Seed[]>(STORAGE_KEYS.seeds, []);
  },
  saveSeeds(seeds: Seed[]): void {
    write(STORAGE_KEYS.seeds, seeds);
  },
  loadTraces(): DailyTrace[] {
    return read<DailyTrace[]>(STORAGE_KEYS.traces, []);
  },
  saveTraces(traces: DailyTrace[]): void {
    write(STORAGE_KEYS.traces, traces);
  },
  loadSettings(): Settings {
    return { ...defaultSettings, ...read<Partial<Settings>>(STORAGE_KEYS.settings, {}) };
  },
  saveSettings(settings: Settings): void {
    write(STORAGE_KEYS.settings, settings);
  },
  loadTheme(): ThemeName | null {
    return read<ThemeName | null>(STORAGE_KEYS.theme, null);
  },
  saveTheme(theme: ThemeName): void {
    write(STORAGE_KEYS.theme, theme);
  },
  /** Date string (localDateKey) the late-night theme offer was last dismissed. */
  loadRitualOfferDismissed(): string | null {
    return read<string | null>(STORAGE_KEYS.ritualOffer, null);
  },
  saveRitualOfferDismissed(dateKey: string): void {
    write(STORAGE_KEYS.ritualOffer, dateKey);
  },
  clearAll(): void {
    if (!isBrowser()) return;
    Object.values(STORAGE_KEYS).forEach((k) => window.localStorage.removeItem(k));
  },
};
