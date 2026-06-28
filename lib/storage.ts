import type { Seed, DailyTrace, Settings, ThemeName, Mood, Energy } from "./types";
import { deserializeSeeds, deserializeTraces } from "./serialize";
import type { Coords } from "./geo";

export type LastPick = { mood?: Mood; energy?: Energy };

export const STORAGE_KEYS = {
  seeds: "tdd.seeds",
  traces: "tdd.traces",
  theme: "tdd.theme",
  settings: "tdd.settings",
  ritualOffer: "tdd.ritualOfferDismissed",
  samplesPlanted: "tdd.samplesPlanted",
  lastPick: "tdd.lastPick",
  introSeen: "tdd.introSeen",
  home: "tdd.home",
  reminders: "tdd.reminders",
} as const;

export const defaultSettings: Settings = {
  theme: "warm_paper",
  aiMode: "mock",
  quietHoursStart: 23,
  quietHoursEnd: 8,
  maxRemindersPerDay: 3,
  nudgesEnabled: false,
  soundEnabled: false,
};

export type RemindersToday = { date: string; count: number };

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
    // Validate on load so a corrupt/partial record can't crash the garden.
    return deserializeSeeds(read<unknown>(STORAGE_KEYS.seeds, []));
  },
  saveSeeds(seeds: Seed[]): void {
    write(STORAGE_KEYS.seeds, seeds);
  },
  loadTraces(): DailyTrace[] {
    return deserializeTraces(read<unknown>(STORAGE_KEYS.traces, []));
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
  /** Whether the current garden is the first-run sample set (shows a note). */
  loadSamplesPlanted(): boolean {
    return read<boolean>(STORAGE_KEYS.samplesPlanted, false);
  },
  saveSamplesPlanted(v: boolean): void {
    write(STORAGE_KEYS.samplesPlanted, v);
  },
  /** The last mood/energy the user picked in the Now flow, to pre-select next time. */
  loadLastPick(): LastPick {
    return read<LastPick>(STORAGE_KEYS.lastPick, {});
  },
  saveLastPick(pick: LastPick): void {
    write(STORAGE_KEYS.lastPick, pick);
  },
  /** Whether the user has seen the first-open intro. */
  loadIntroSeen(): boolean {
    return read<boolean>(STORAGE_KEYS.introSeen, false);
  },
  saveIntroSeen(v: boolean): void {
    write(STORAGE_KEYS.introSeen, v);
  },
  /** A coarse, on-device "home" location used to sense at-home vs away. */
  loadHome(): Coords | null {
    return read<Coords | null>(STORAGE_KEYS.home, null);
  },
  saveHome(c: Coords | null): void {
    write(STORAGE_KEYS.home, c);
  },
  /** How many gentle reminders were sent today (for the daily budget). */
  loadReminders(): RemindersToday | null {
    return read<RemindersToday | null>(STORAGE_KEYS.reminders, null);
  },
  saveReminders(r: RemindersToday): void {
    write(STORAGE_KEYS.reminders, r);
  },
  clearAll(): void {
    if (!isBrowser()) return;
    Object.values(STORAGE_KEYS).forEach((k) => window.localStorage.removeItem(k));
  },
};
