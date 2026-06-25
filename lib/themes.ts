import type { ThemeName } from "./types";

export type ThemeTokens = {
  background: string;
  surface: string;
  surfaceSoft: string;
  textPrimary: string;
  textSecondary: string;
  textMuted: string;
  accent: string;
  accentSoft: string;
  border: string;
};

export const themes: Record<ThemeName, ThemeTokens> = {
  warm_paper: {
    background: "#F8F4EC",
    surface: "#FFFDF8",
    surfaceSoft: "#F1EADF",
    textPrimary: "#26231F",
    textSecondary: "#746C60",
    textMuted: "#A49A8A",
    accent: "#7D9A7A",
    accentSoft: "#DDE8D8",
    border: "#E6DCCC",
  },
  dusk_garden: {
    background: "#EEF0F4",
    surface: "#FAF7F2",
    surfaceSoft: "#E7E1EC",
    textPrimary: "#252A35",
    textSecondary: "#687083",
    textMuted: "#9AA1B2",
    accent: "#D7A35F",
    accentSoft: "#F2DFC1",
    border: "#D8D5DF",
  },
  minimal_ios: {
    background: "#F7F7F8",
    surface: "#FFFFFF",
    surfaceSoft: "#EFEFF3",
    textPrimary: "#111111",
    textSecondary: "#666666",
    textMuted: "#999999",
    accent: "#6E8FBF",
    accentSoft: "#E7EEF8",
    border: "#E5E5EA",
  },
  field_notebook: {
    background: "#F1F4EA",
    surface: "#FFFDF4",
    surfaceSoft: "#E3EAD8",
    textPrimary: "#243024",
    textSecondary: "#65715F",
    textMuted: "#9AA18F",
    accent: "#758B5A",
    accentSoft: "#DDE8C8",
    border: "#D7DDC8",
  },
  soft_ritual: {
    background: "#27231F",
    surface: "#332D27",
    surfaceSoft: "#40372F",
    textPrimary: "#FFF3E0",
    textSecondary: "#D9C7AE",
    textMuted: "#A99883",
    accent: "#D6A45F",
    accentSoft: "#5A442C",
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
    "--border": t.border,
    "--shadow-card": shadow.card,
  };
}
