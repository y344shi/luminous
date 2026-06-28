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
const CORE_DIR = resolve(process.cwd(), "packages/core");
const DIRS = [resolve(process.cwd(), "lib"), CORE_DIR];
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

/**
 * Boundary guard: @luminous/core (packages/core) must never reach back into the app
 * (the `@/` alias or a `../` escape). If it did, the package would no longer be
 * self-contained and couldn't be lifted into the React Native / iOS build.
 */
const BACK_EDGE = [
  /from\s+["']@\/[^"']+["']/, // the app alias
  /from\s+["']\.\.\//, // escaping packages/core
  /import\(\s*["']@\/[^"']+["']/, // inline app import
];

describe("core boundary — packages/core never imports the app (RN/iOS-portable)", () => {
  const inCore = coreFiles.filter(({ dir }) => dir === CORE_DIR);
  it("scans the extracted core", () => {
    expect(inCore.length).toBeGreaterThanOrEqual(10);
  });
  inCore.forEach(({ dir, file }) => {
    it(`${file} imports only @core / external — no @/ or ../`, () => {
      const src = readFileSync(resolve(dir, file), "utf8");
      const hits = BACK_EDGE.filter((re) => re.test(src)).map((re) => re.source);
      expect(hits, `${file} reaches back into the app: ${hits.join(", ")}`).toEqual([]);
    });
  });
});
