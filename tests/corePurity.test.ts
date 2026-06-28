import { describe, it, expect } from "vitest";
import { readFileSync, readdirSync } from "node:fs";
import { resolve } from "node:path";

/**
 * The whole point of keeping logic in lib/ is that it's framework-free, so it
 * can be lifted into packages/core for the React Native / iOS build (see
 * docs/ios-roadmap.md). This guard enforces that precondition: every lib module
 * EXCEPT the store glue must import nothing from React / Next / Zustand and must
 * not be a client component. If this fails, a UI concern leaked into the core.
 */
const DIRS = [resolve(process.cwd(), "lib"), resolve(process.cwd(), "packages/core")];
// store.ts is the single allowed React/Zustand boundary ("use client" + create).
const ALLOWED_IMPURE = new Set(["store.ts"]);

const FORBIDDEN = [
  /from\s+["']react["']/,
  /from\s+["']react\/[^"']+["']/,
  /from\s+["']next["']/,
  /from\s+["']next\/[^"']+["']/,
  /from\s+["']zustand["']/,
  /^\s*["']use client["']/m,
];

const coreFiles = DIRS.flatMap((dir) =>
  readdirSync(dir)
    .filter((f) => f.endsWith(".ts"))
    .filter((f) => !ALLOWED_IMPURE.has(f))
    .map((f) => ({ dir, file: f }))
);

describe("core purity — lib/ stays framework-free (iOS-ready)", () => {
  it("scans a meaningful number of core modules", () => {
    expect(coreFiles.length).toBeGreaterThanOrEqual(10);
  });

  coreFiles.forEach(({ dir, file }) => {
    it(`${file} imports no React/Next/Zustand and isn't a client component`, () => {
      const src = readFileSync(resolve(dir, file), "utf8");
      const hits = FORBIDDEN.filter((re) => re.test(src)).map((re) => re.source);
      expect(hits, `${file} leaked: ${hits.join(", ")}`).toEqual([]);
    });
  });
});
