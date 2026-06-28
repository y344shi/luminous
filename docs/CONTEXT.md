# Luminous — Shared Context (read me first)

Single source of truth for any Claude/agent working on **luminous** (《今天别消失》)
on **any machine** — MacBook *and* Windows WSL. Claude's conversation history does
**not** sync across machines; **this file and the committed docs it indexes are how
context travels.** Pull before you start, commit what matters before you stop.

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

## Branches — what each holds
| branch | contents |
| --- | --- |
| `main` | baseline + shared meta (this file) |
| `glass` | web Direction A · Liquid Glass (bubble field) |
| `sense` | web Direction B · Living World (scene/sensing) |
| `craft` | web Direction C · Calm Ritual (paper notebook) |
| `ios-glass` | **native SwiftUI port** (`ios/Luminous/`) + the glass direction |

## Web directions — status (see `docs/overnight-plan.md` for the full 20-item plan)
- **glass**: A1 refraction · A2 caustic rim · A3 depth · A4 gooey · A5 dreamier — *(A6, A7 pending)*
- **sense**: B1 wallpapers · B2 parallax · B3 café-nav (Overpass) · B4 weather (open-meteo) · B5 day-grade — *(B6, B7 pending)*
- **craft**: C1 timeline · C2 paper-home · C3 haptics+chime · C4 keepsake card · C5 perf+a11y — *(C6, C7 pending)*

A 5-minute overnight loop rotates glass→sense→craft, one green committed step per
tick (`docs/tick-playbook.md`).

## iOS port — status
`ios/Luminous/` is a full SwiftUI app mirroring the web domain layer
(`Domain`/`Store`/`Scoring`/`SeedParser`/`SemanticTime`/`Theme`/`Copy`/`DesignKit`)
with `HomeView`/`NowView`/`GardenView`/`TracesView`/`SettingsView`/`AddSeedView`.
`GlassField.swift` ports web **glass 1–5** (TimelineView + Canvas, honors Reduce
Motion). Build on the **Mac** with Xcode. Plan: `docs/ios-roadmap.md`.

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
- `docs/overnight-plan.md` — the 3-direction, 20-item plan + checkboxes.
- `docs/TIMELINE.md` — Notion-loadable git history (auto-generated).
- `docs/iteration-log.md` — per-cycle journal.
- `docs/ios-roadmap.md` — native plan.
- `docs/scene-library.md` — ~100 scenarios + transparent/3D asset sources.
- `docs/GALLERY.md` — latest Home screenshot per direction.
