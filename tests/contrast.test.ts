import { describe, it, expect } from "vitest";
import { themes, themeOrder } from "@/lib/themes";

// WCAG relative luminance + contrast ratio.
function lum(hex: string): number {
  const c = hex.replace("#", "");
  const r = parseInt(c.slice(0, 2), 16) / 255;
  const g = parseInt(c.slice(2, 4), 16) / 255;
  const b = parseInt(c.slice(4, 6), 16) / 255;
  const f = (v: number) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);
  return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
}
function ratio(a: string, b: string): number {
  const l1 = lum(a);
  const l2 = lum(b);
  const hi = Math.max(l1, l2);
  const lo = Math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

// fg key, bg key, minimum ratio. Body/secondary → AA 4.5; subtle muted → 3.0
// (reserved for non-essential labels/hints); the on-accent button label → 4.5.
const checks: [keyof typeof themes.warm_paper, keyof typeof themes.warm_paper, number][] = [
  ["textPrimary", "surface", 4.5],
  ["textPrimary", "background", 4.5],
  ["textSecondary", "surface", 4.5],
  ["textSecondary", "surfaceSoft", 4.5],
  ["textMuted", "surface", 3.0],
  ["textMuted", "surfaceSoft", 3.0],
  ["onAccent", "accent", 4.5],
];

describe("theme contrast (WCAG)", () => {
  themeOrder.forEach((name) => {
    const t = themes[name];
    checks.forEach(([fg, bg, min]) => {
      it(`${name}: ${fg} on ${bg} ≥ ${min}`, () => {
        expect(ratio(t[fg], t[bg])).toBeGreaterThanOrEqual(min);
      });
    });
  });
});
