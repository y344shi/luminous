import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { themeOrder, themeToCssVars } from "@/lib/themes";

// The runtime colors live in app/globals.css ([data-theme] blocks); themes.ts
// mirrors them for the switcher swatches + the contrast test. The two can drift
// silently. This test parses globals.css and asserts every color token matches
// themeToCssVars(name) exactly. (--shadow-card is per-theme in CSS but a shared
// constant in TS, so it's excluded.)
const css = readFileSync(resolve(process.cwd(), "app/globals.css"), "utf8");

function cssVarsFor(theme: string): Record<string, string> {
  const re = new RegExp(`\\[data-theme="${theme}"\\]\\s*\\{([^}]*)\\}`);
  const block = css.match(re);
  if (!block) throw new Error(`no [data-theme="${theme}"] block in globals.css`);
  const vars: Record<string, string> = {};
  for (const m of block[1].matchAll(/(--[a-z-]+):\s*([^;]+);/g)) {
    vars[m[1]] = m[2].trim().toLowerCase();
  }
  return vars;
}

describe("token sync — globals.css ↔ themes.ts", () => {
  themeOrder.forEach((name) => {
    it(`${name} color tokens match`, () => {
      const fromCss = cssVarsFor(name);
      const fromTs = themeToCssVars(name);
      for (const [key, val] of Object.entries(fromTs)) {
        if (key === "--shadow-card") continue;
        expect(fromCss[key], `${name} ${key}`).toBe(val.toLowerCase());
      }
    });
  });

  it("every theme has a globals.css block", () => {
    expect(themeOrder.every((t) => css.includes(`[data-theme="${t}"]`))).toBe(true);
  });
});
