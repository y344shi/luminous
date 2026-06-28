# 《今天别消失》 · luminous

**An AI life-anchor — not a todo app.** It catches a soft wish (a *Seed*) and hands
it back at the right moment, so today didn't completely disappear. Tender,
ISFP-friendly: **no shame, no streaks, no deadlines, no priorities, no percentages.**
Doing *a little* always counts; skipping never "fails".

> Read [`docs/product-philosophy.md`](docs/product-philosophy.md) before touching tone or copy.

## The core loop (never breaks)
**Add a Seed → a Now opportunity → Complete / Partial / Skipped → a Daily Trace.**
A trace is "today didn't disappear, because ___" — a kept moment, not an achievement.

## What makes it keen — on-device sensor fusion
luminous reads coarse, **on-device** senses to pick *which tiny wish fits right now*,
then nudges (never commands). Every signal is soft, capped, and degrades to nothing
when unavailable. **Nothing raw ever leaves the device.**

- **time** (morning…late-night, with a hard late-night safety gate) · **place**
  (coarse, opt-in) · **motion** (still/walking/transit) · **ambient loudness** (opt-in
  mic) · **dwell** (how long at the desk today) · **weather** (open-meteo, for a saved
  coarse home) · **battery** (a soft "winding down" proxy) · **heart rate → arousal**
  (iOS HealthKit seam).

One hook, `useSensedSignals()`, fuses them for both the home and the deliberate
`/now` flow. Pure classifiers live in `lib/`; each contributes a capped bonus in
`lib/scoring.ts`. See [`docs/CONTEXT.md`](docs/CONTEXT.md) for the full map.

## Three looks, one core
A single shared core with runtime-swappable **skins** (Settings → 外观风格):

- **glass** — wishes float as boxless illustrations around a glowing orb.
- **ocean** — the same field with buoyancy; wishes rise to the surface.
- **paper** — a warm field-notebook with pressed-flower marks.

Every wish is a small **lifestyle illustration**, picked from 8 swappable library
styles (Settings → 插画风格) and drawn per category.

## Run / verify
```bash
npm run dev        # local dev → http://localhost:3000
npm run typecheck  # tsc --noEmit — stays clean
npm test           # vitest — 270+ tests, stays green
npm run build      # next build — all routes compile
```
Node 22+. (On WSL: `export PATH="$HOME/.local/bin:$PATH"`.)

## Layout
- `lib/` — pure, React-free domain logic (scoring is `rng`-injectable & tested).
- `components/` — UI, grouped by feature; `home/shared` holds the field, sensing
  hooks, and illustration packs; `home/skins` holds the three looks.
- `app/` — routes. `docs/` — living documentation. `tests/` — Vitest.

## Privacy
No hardcoded API keys. Only coarse, derived context ever feeds the ranking; raw
audio, heart rate, and precise location **never leave the device**.

---
*Built with Next.js · React · Tailwind · Zustand · TypeScript. iOS lives in `ios/`
(SwiftUI); a React Native + shared-core unification is under consideration — see
[`docs/CONTEXT.md`](docs/CONTEXT.md).*
