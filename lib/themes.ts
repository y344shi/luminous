import type { ThemeName } from "@core/types";

export type ThemeTokens = {
  background: string;
  surface: string;
  surfaceSoft: string;
  textPrimary: string;
  textSecondary: string;
  textMuted: string;
  accent: string;
  accentSoft: string;
  /** Darker accent for accent-COLORED text (links, active nav) on light surfaces. */
  accentText: string;
  /** Foreground color for text/icons placed ON the accent (e.g. primary button). */
  onAccent: string;
  border: string;
};

export const themes: Record<ThemeName, ThemeTokens> = {
  warm_paper: {
    background: "#F8F4EC",
    surface: "#FFFDF8",
    surfaceSoft: "#F1EADF",
    textPrimary: "#26231F",
    textSecondary: "#6B6357",
    textMuted: "#827868",
    accent: "#7D9A7A",
    accentSoft: "#DDE8D8",
    accentText: "#4C6549",
    onAccent: "#211E19",
    border: "#E6DCCC",
  },
  dusk_garden: {
    background: "#EEF0F4",
    surface: "#FAF7F2",
    surfaceSoft: "#E7E1EC",
    textPrimary: "#252A35",
    textSecondary: "#565E6E",
    textMuted: "#666E80",
    accent: "#D7A35F",
    accentSoft: "#F2DFC1",
    accentText: "#7A5822",
    onAccent: "#221A12",
    border: "#D8D5DF",
  },
  minimal_ios: {
    background: "#F7F7F8",
    surface: "#FFFFFF",
    surfaceSoft: "#EFEFF3",
    textPrimary: "#111111",
    textSecondary: "#5E5E5E",
    textMuted: "#79797F",
    accent: "#6E8FBF",
    accentSoft: "#E7EEF8",
    accentText: "#3F6196",
    onAccent: "#0E2236",
    border: "#E5E5EA",
  },
  field_notebook: {
    background: "#F1F4EA",
    surface: "#FFFDF4",
    surfaceSoft: "#E3EAD8",
    textPrimary: "#243024",
    textSecondary: "#586353",
    textMuted: "#727B66",
    accent: "#758B5A",
    accentSoft: "#DDE8C8",
    accentText: "#4E6438",
    onAccent: "#131A0E",
    border: "#D7DDC8",
  },
  soft_ritual: {
    background: "#27231F",
    surface: "#332D27",
    surfaceSoft: "#40372F",
    textPrimary: "#FFF3E0",
    textSecondary: "#D9C7AE",
    textMuted: "#B5A48E",
    accent: "#D6A45F",
    accentSoft: "#5A442C",
    accentText: "#D6A45F",
    onAccent: "#2A2012",
    border: "#51463C",
  },
};

export const themeMeta: Record<ThemeName, { label: string; feeling: string }> = {
  warm_paper: { label: "暖纸", feeling: "下午桌上的一张纸" },
  dusk_garden: { label: "黄昏花园", feeling: "太阳落下前的 20 分钟" },
  minimal_ios: { label: "极简", feeling: "干净、留白、不催促" },
  field_notebook: { label: "野外笔记", feeling: "坐在草地边写一句话" },
  soft_ritual: { label: "睡前仪式", feeling: "温水、台灯、不补救人生" },
};

export const themeOrder: ThemeName[] = [
  "warm_paper",
  "dusk_garden",
  "minimal_ios",
  "field_notebook",
  "soft_ritual",
];

export const spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48,
};

export const radius = {
  card: 24,
  button: 999,
  sheet: 32,
};

export const shadow = {
  card: "0 8px 30px rgba(60, 45, 30, 0.06)",
};

/** Convert a theme's tokens into CSS custom property declarations. */
export function themeToCssVars(name: ThemeName): Record<string, string> {
  const t = themes[name];
  return {
    "--bg": t.background,
    "--surface": t.surface,
    "--surface-soft": t.surfaceSoft,
    "--text": t.textPrimary,
    "--text-secondary": t.textSecondary,
    "--text-muted": t.textMuted,
    "--accent": t.accent,
    "--accent-soft": t.accentSoft,
    "--accent-text": t.accentText,
    "--on-accent": t.onAccent,
    "--border": t.border,
    "--shadow-card": shadow.card,
  };
}
