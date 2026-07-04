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
npm run dev:https  # HTTPS dev (self-signed) → test mic/motion sensors on a phone
npm run typecheck  # tsc --noEmit — stays clean
npm test           # vitest — 290+ tests, stays green
npm run build      # next build — all routes compile
```
Node 22+. (On WSL: `export PATH="$HOME/.local/bin:$PATH"`.)

**Testing the senses on a phone:** the mic (感受周围) and motion need a *secure
context* — `localhost` works on the same machine, but a plain-http LAN IP does not.
Run `npm run dev:https`, open `https://<your-LAN-IP>:3000` on the phone, accept the
self-signed-cert warning once, then 感受周围 can open the mic. (A tunnel like
`ngrok http 3000` gives a real https URL instead.)

## Layout
- `packages/core/` — **`@luminous/core`**: the framework-free domain (recommender,
  sensor fusion, ambient/context, seed parsing, traces). Imported via `@core/*`;
  guarded React-free *and* app-free — the shared brain for a future RN/iOS build.
- `lib/` — the platform boundary only (`store`, `storage`, browser/UI helpers).
- `components/` — UI, grouped by feature; `home/shared` holds the field, sensing
  hooks, and illustration packs; `home/skins` holds the three looks.
- `app/` — routes. `docs/` — living documentation. `tests/` — Vitest.

## The native app — iOS · macOS · watchOS (`ios/`)
A full SwiftUI implementation, now the most capable build — see
[`ios/README.md`](ios/README.md). Highlights:

- **On-device LLM** (Apple FoundationModels): parses wishes, breaks tasks into
  tiny steps with live resources (real walking routes, themed vocab, camera
  translation, a recipe → shopping list → nearest market), estimates the day's
  mentality as one clamped scoring tilt, writes the weekly review. The LLM
  decides content; code decides truth and safety — hard gates are never prompts.
- **The planetarium home**: wishes orbit a physics-rendered black hole on a real
  gravity sim; **记忆星座** turns every trace into a permanent star in your sky,
  with a birth ceremony on completion.
- **Awareness**: motion, weather, kind-diverse nearby places, learned home/work
  (coarse cells, raw coords never stored), a life-event log → rhythm, recurrence,
  fit-learning.
- **SwiftData multi-profile** ("gardens"), CloudKit-sync-ready; notifications
  wired but off by default; `swift test` green gate (49 tests pin the safety rules).

## Privacy
No hardcoded API keys. Only coarse, derived context ever feeds the ranking; raw
audio, heart rate, and precise location **never leave the device**. On iOS all
AI runs on-device (Apple Intelligence); only a coarse coordinate reaches
open-meteo/MapKit.

---
*Web: Next.js · React · Tailwind · Zustand · TypeScript. Native: SwiftUI +
FoundationModels + SwiftData in `ios/` (SwiftUI chosen; the RN question is
settled). Cross-machine map: [`docs/CONTEXT.md`](docs/CONTEXT.md).*
