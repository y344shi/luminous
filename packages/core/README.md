# @luminous/core

The framework-free heart of luminous — pure TypeScript with **no React / Next /
browser** dependencies, so it can be shared by the web app *and* a future React
Native / iOS build (kills the Swift logic duplication). The web app imports it via
the `@core/*` path alias (tsconfig + vitest).

**Extraction is incremental** — modules move here one safe slice at a time, staying
green. First slice: the on-device sensing classifiers (sensors / dwell / battery).
Guarded framework-free by `tests/corePurity.test.ts`.
