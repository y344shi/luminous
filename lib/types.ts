// Core domain types for 《今天别消失》 / Today Don't Disappear
// A context-aware AI life-anchor app: soft wishes (Seeds) → opportunities → traces.

export type SeedCategory =
  | "body"
  | "creation"
  | "connection"
  | "exploration"
  | "recovery"
  | "learning"
  | "aesthetic";

export type Energy = "low" | "medium" | "high";

export type Mood =
  | "empty"
  | "tired"
  | "anxious"
  | "okay"
  | "alive"
  | "avoidant"
  | "lonely"
  | "want_love"
  | "unknown";

export type SemanticTime =
  | "morning"
  | "lunch"
  | "afternoon"
  | "after_work"
  | "evening"
  | "late_night"
  | "weekend"
  | "transit"; // "on the move" — used as a soft contextual window for tiny actions

export type LocationType =
  | "anywhere"
  | "home"
  | "work"
  | "outdoor"
  | "downtown"
  | "computer"
  | "transit"
  | "unknown";

export type SeedStatus = "active" | "sleeping" | "completed" | "archived";

export type Seed = {
  id: string;
  rawText: string;
  title: string;
  description?: string;

  categories: SeedCategory[];
  minimumAction: string;
  estimatedDurationMin: number;
  energyRequired: Energy;
  locationType: LocationType;
  preferredTimes: SemanticTime[];
  triggerConditions: string[];

  status: SeedStatus;

  createdAt: string;
  updatedAt: string;
};

export type ContextSnapshot = {
  timestamp: string;
  semanticTime: SemanticTime;

  mood: Mood;
  energy: Energy;
  freeMinutes?: number;

  isLateNight: boolean;
  isWeekend?: boolean;
  isOutdoorWeatherGood?: boolean;

  locationHint?: LocationType;

  deviceContext?: {
    isMobile: boolean;
    isAtComputer?: boolean;
  };

  // Fused sensor signals (all derived on-device; absent when unavailable/denied).
  activity?: "still" | "walking" | "transit"; // motion / accelerometer
  ambient?: "quiet" | "lively"; // ambient loudness (opt-in mic)
  arousal?: "calm" | "elevated"; // heart rate (iOS HealthKit; unused on web)
};

export type Opportunity = {
  id: string;
  seedId: string;
  score: number;
  reason: string;
  suggestedAction: string;
  notificationText: string;
  createdAt: string;
};

export type DailyTrace = {
  id: string;
  date: string; // YYYY-MM-DD
  seedId?: string;
  opportunityId?: string;
  text: string;
  category?: SeedCategory;
  partial?: boolean;
  createdAt: string;
};

export type ThemeName =
  | "warm_paper"
  | "dusk_garden"
  | "minimal_ios"
  | "field_notebook"
  | "soft_ritual";

export type Settings = {
  theme: ThemeName;
  aiMode: "mock" | "real";
  quietHoursStart: number; // hour 0-23
  quietHoursEnd: number; // hour 0-23
  maxRemindersPerDay: number;
  nudgesEnabled: boolean;
  soundEnabled: boolean;
  aesthetic: import("./aesthetic").Aesthetic;
};
