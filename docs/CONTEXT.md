# Luminous — Shared Context (read me first)

Single source of truth for any Claude/agent working on **luminous** (《今天别消失》)
on **any machine** — MacBook *and* Windows WSL. Claude's conversation history does
**not** sync across machines; **this file and the committed docs it indexes are how
context travels.** Pull before you start, commit what matters before you stop.


> **Restructure DONE:** one trunk per platform, shared core + swappable skins
> (glass / ocean / paper) via `lib/aesthetic.ts` (runtime-switchable in Settings →
> 外观风格, or `NEXT_PUBLIC_AESTHETIC` default). Web → `luminous-trunk` → `main`;
> iOS mirrors it with an `Aesthetic` enum on `ios-glass`. The old per-aesthetic
> branches (web glass/sense/craft/ocean, iOS ios-sense/ios-craft) were folded in
> and deleted — preserved as `archive/*` tags. See `docs/architecture-skins.md`.

## What luminous is
An AI **life-anchor** app (NOT a todo/productivity app): it catches a soft wish (a
*Seed*) and hands it back at the right moment so today didn't completely disappear.
Tender, ISFP-friendly, no shame / streaks / deadlines. Read
`docs/product-philosophy.md` before touching tone or copy.

Core loop (must never break): **Add Seed → Now Opportunity → Complete/Partial → Daily Trace.**

## Machines & layout (important — paths differ)
- **Windows WSL**: monorepo at `~/foundation`; the app lives at
  `dreams/seize_the_day`; it is mirrored to the luminous repo with
  `git subtree push --prefix=dreams/seize_the_day luminous <branch>`.
  (Linux node v22 at `~/.local/bin` — `export PATH="$HOME/.local/bin:$PATH"`.)
- **MacBook**: clones the **luminous** repo directly (app at the repo root, so
  `ios/` and `app/` are top-level). Xcode / the iOS build live here.
- **Remote**: `git@github.com:y344shi/luminous.git`

So a file at `dreams/seize_the_day/docs/X` on WSL appears at `docs/X` on the Mac.
Put shared docs **inside the app dir** on WSL or they won't reach the Mac.

## Branches — what each holds (post-consolidation)
| branch | contents |
| --- | --- |
| `main` | the web trunk — shared core + all 3 skins (`luminous-trunk` pushes here) |
| `ios-glass` | the **native trunk** — the full iOS/macOS/watchOS app (see below) |
| `ios-aware` / `macos` | working branches for the native app; currently identical to `ios-glass` (kept fast-forwarded) |
| `archive/*` | retired direction branches (glass/sense/craft/ocean, ios-sense/ios-craft) — reference only |

## Skins — status (one core, three looks; backlog in `docs/next-steps.md`)
- **glass** — bubble field round a glowing orb: the 3 top wishes float as **boxless
  illustrations + titles** (custom physics, gyro lean, condense-from-light entrance);
  lesser wishes are small glass dots; a soft warm bloom holds the orb. ✅
- **ocean** — the same field with `buoyancy`: wishes rise from the floor and scatter
  in the upper band (surface); weather can tint the field. ✅
- **paper** — warm field-notebook: hand-laid notes + pressed-flower marks · haptics ·
  keepsake card. (Keeps its own emblems; no illustration packs / no weather tint.) ✅
- **shared core** (every skin inherits): SceneBackground (mesh/parallax/day-grade),
  the central **orb** (sensed scene + label), **floating illustrated wishes** (the
  illustration packs, below), the **sensing fusion** (below), the wish **tap-sheet**,
  feedback, keepsake, webpush. Runtime skin picker in Settings → 外观风格.
  *(The old Overpass "café nav" NavLayer was a misread of the design and is deleted.)*

A 5-minute overnight loop works **skins + core on `luminous-trunk` → main**, one
green committed step per tick (`docs/tick-playbook.md`).

## Sensing fusion (on-device — the keen part)
The recommender fuses coarse, on-device senses to pick *which tiny wish fits now*.
**Nothing raw leaves the device**; each signal is soft + capped and degrades to
nothing when unavailable. One hook — `components/home/shared/useSensedSignals.ts` —
bundles them, read by both home skins **and** the Now flow (`/now`), so the
deliberate ask is as keen as the casual home. Pure classifiers live in `lib/`
(`sensors`, `dwell`, `weather`, `battery`); each has a capped `*Bonus` in
`lib/scoring.ts` folded into `scoreSeed`.

| signal | source | bonus | status |
| --- | --- | --- | --- |
| time / weekday / late-night | clock | timeFit + late-night **safety gate** | live |
| location | coarse geo (opt-in) | locationFit | live |
| motion → still/walking/transit | accelerometer | sensorBonus | live |
| loudness → quiet/lively | mic (opt-in) | sensorBonus | live |
| dwell → desk-min today | localStorage | dwellBonus | live |
| weather → kind | open-meteo (saved home) | weather_good + day-line + tint | live |
| battery low | Battery API | batteryBonus | live (Chrome/Android) |
| arousal → calm/elevated | **heart rate** | sensorBonus | **iOS seam** (HealthKit) |

The day-line surfaces several (e.g. `周三 · 下午 · 在电脑前 · 晴 · 坐了一会`).
End-to-end coverage: `tests/fusionIntegration.test.ts`.

## Illustration packs (every wish is a small lifestyle drawing)
8 library "looks" (Open Doodles / Storyset / Pixeltrue / Blush / Humaaans / Open
Peeps / unDraw / DrawKit) in `components/home/shared/illustrationPacks.tsx`, each
**category-aware** (a scene per wish category). Code-drawn for now; real downloaded
assets can drop behind the same `IllustrationArt` interface. Picked in Settings →
插画风格 (`settings.illustrationStyle`); `illustrationCategory` varies the look across
a wish's categories. Shown on the home wishes, tap-sheet, Garden, Now, detail, add —
everywhere except the keepsake `TraceCard` (kept warm by decision). See
`docs/scene-library.md` for sources/licenses.

## iOS — status (one trunk: `ios-glass`; **the native app pulled ahead**)
`ios/` is a full SwiftUI app for **iOS + macOS + watchOS** from one project —
see **`ios/README.md`** (the front door) and `ios/OVERNIGHT-SESSION.md` (the
"aware" build record). As of 2026-07 it has, beyond the web:

- **On-device LLM** (Apple FoundationModels): seed parsing, task breakdown with
  live resources (walking routes / themed vocab / camera translate / recipe →
  shopping list → nearest market), review quiz, creation/connection sparks,
  mentality estimate (one clamped scoring term), reason-writer, weekly review,
  pursuit merge. House law: @Generable output + deterministic fallback +
  ForbiddenWords; hard gates in code, never prompts.
- **Sensing fusion ported and surpassed**: motion, weather, kind-diverse nearby
  places (MapKit), learned home/work cells, a SwiftData life-event log → rhythm
  histograms, recurrence + fit-learning. (HealthKit arousal still needs the paid
  program; mic loudness still stubbed.)
- **The planetarium**: black-hole home on a real gravity sim (velocity-Verlet),
  记忆星座 (traces = permanent stars + birth ceremony), scouted shooting stars.
- **SwiftData multi-profile "gardens"** (CloudKit-ready), notifications default-OFF
  behind quiet hours + the absolute late-night rule.
- **Test harness**: `cd ios && swift test` (SwiftPM package over the pure core;
  49 tests pin the safety gates).

**The RN-vs-SwiftUI call is settled: SwiftUI.** The remaining parity direction is
now web ← iOS (port `Rhythm`/`Places`/`Recurrence`/`PlanKit` patterns back into
`packages/core` when the web needs them). Sensor brief `docs/ios-sensor-port.md`
is DONE; `docs/ios-roadmap.md` items native push/widgets/Siri/complication remain.

## Cross-machine sync protocol
**Start** of any session, on either machine:
1. `git fetch --all`; pull/checkout the branch you'll work on.
2. Read **this file** + `docs/TIMELINE.md` (auto-generated git history).

**End** of any session:
3. Commit code; append to `docs/iteration-log.md`.
4. Regenerate the timeline: `npm run timeline` (or `node scripts/gen-timeline.mjs`).
5. If the big picture changed, update the status lines in **this file**.
6. Push the branch (WSL: `git subtree push …`; Mac: `git push`).

Never count on chat history carrying over between machines — write it here.

## Doc index
- `CLAUDE.md` / `AGENTS.md` — working rules (auto-loaded each session).
- `docs/product-philosophy.md` — tone/voice (read before copy changes).
- `docs/architecture-skins.md` — the shared-core + swappable-skins design.
- `docs/next-steps.md` — the live backlog (one item per tick).
- `docs/overnight-plan.md` — the original 3-direction 20-item plan (historical).
- `docs/TIMELINE.md` — Notion-loadable git history (auto-generated).
- `docs/iteration-log.md` — per-cycle journal.
- `ios/README.md` — the native app's front door (features, build, layout, law).
- `ios/TOUR.md` — the illustrated codebase tour (functions ↔ screenshots ↔ diagrams).
- `ios/VISION-AUDIT.md` — native product/architecture audit + build order (shipped).
- `ios/OVERNIGHT-SESSION.md` — the "aware" overnight build record + decisions.
- `docs/ios-roadmap.md` — native plan (push/widgets/Siri/complication remain).
- `docs/ios-sensor-port.md` — brief to port the sensing fusion to iOS (**done**).
- `docs/INTEGRATION.md` — how the pieces fit + how to integrate RN/iOS on @luminous/core.
- `docs/scene-library.md` — ~100 scenarios + illustration-library sources/licenses.
- `docs/GALLERY.md` — latest Home screenshot per **skin** (glass/ocean/paper).
