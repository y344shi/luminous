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
| `ios-glass` | the iOS trunk — `ios/Luminous/` core + `Aesthetic` enum + all 3 skins |
| `archive/*` | retired direction branches (glass/sense/craft/ocean, ios-sense/ios-craft) — reference only |

## Skins — status (one core, three looks; backlog in `docs/next-steps.md`)
- **glass** — liquid-glass bubble field: refraction · caustic light · depth · gooey · dreamier · gyro · condense-from-light entrance. ✅
- **ocean** — the field with `buoyancy`: rise-from-floor load · caustic surface + light shafts + bubble streams. ✅
- **paper** — warm field-notebook: haptics · keepsake card · hand-laid notes + pressed-flower marks. ✅
- **shared core** (every skin inherits): SceneBackground (mesh/parallax/weather/day-grade), NavLayer (Overpass café nav), SceneWindow (living orb), feedback, keepsake, webpush. Runtime skin picker in Settings.

A 5-minute overnight loop works **skins + core on `luminous-trunk` → main**, one
green committed step per tick (`docs/tick-playbook.md`).

## iOS — status (one trunk: `ios-glass`)
`ios/Luminous/` is a full SwiftUI app mirroring the web core
(`Domain`/`Store`/`Scoring`/`SeedParser`/`SemanticTime`/`Theme`/`Copy`/`DesignKit`/
`Feedback`/`DayGrade`) with an `Aesthetic` enum + `AestheticField` switching
`GlassField`/`OceanField`(=GlassField buoyancy)/`PaperField`. A time-of-day
`SceneBackground` (MeshGradient) sits behind glass/ocean. **Build on the Mac with
Xcode** (last reconciliation is verified by reading only — confirm it compiles).
Plan: `docs/ios-roadmap.md`.

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
- `docs/ios-roadmap.md` — native plan.
- `docs/scene-library.md` — ~100 scenarios + transparent/3D asset sources.
- `docs/GALLERY.md` — latest Home screenshot per **skin** (glass/ocean/paper).
