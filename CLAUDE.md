# 《今天别消失》 / Today Don't Disappear — Project Guide

An AI **life-anchor** app (NOT a todo/productivity app). It catches a soft wish
(a *Seed*) and hands it back at the right moment so that today didn't completely
disappear. Read `docs/product-philosophy.md` before changing tone or copy.

## Run / verify
```bash
export PATH="$HOME/.local/bin:$PATH"   # Linux node v22 lives here (env's default node is Windows-only)
npm run dev        # local dev
npm run typecheck  # tsc --noEmit  — must stay clean
npm test           # vitest run    — must stay green (31+ tests)
npm run build      # next build    — must compile all routes
```

## The core loop (must NEVER break)
Add Seed (`/add`) → Now Opportunity (`/now`) → Complete / Partial / Skipped → Daily Trace (`/traces`).
Code path: `AddSeedFlow` → `parseSeedMock`/`draftToSeed` → `store` → `NowFlow` → `buildContext` → `recommend` → `buildTrace`.

## Layout
- `lib/` — pure, React-free domain logic (future `packages/core`). Scoring is `rng`-injectable & tested.
- `components/` — UI, grouped by feature. `AppProvider` hydrates store + sets `<html data-theme>`.
- `app/` — 6 routes. `docs/` — living documentation. `tests/` — Vitest.

## Hard rules (product safety)
- No shame, no tasks/deadlines/streaks/priorities/% (`lib/copy.ts` `forbiddenWords`).
- Partial always counts; skipped never "disappears".
- Late-night (`isLateNight`) is a **hard safety gate** in `rankSeeds` — never recommend
  going out / high-energy / long actions; surface stop-loss/rescue only.
- AI never commands, diagnoses, professes love, or pushes all-night work.
- No hardcoded API keys. Only coarse context (no GPS/biometrics) ever leaves the device.

## Committed history is a rule (every change)
Every code-change idea — however small — is **committed**, never left loose in the
working tree. The discipline:
- Work on a **named branch** for the direction (see `docs/overnight-plan.md`), not detached.
- After a green change (`typecheck && test && build`), **commit** with a clear
  `Cycle N: …` (or `<dir> N: …`) subject + the Co-Authored-By trailer.
- **Regenerate the timeline**: `node scripts/gen-timeline.mjs` → `docs/TIMELINE.md`
  (Notion-loadable: branches, commits, dates). Commit it with the change.
- **Push** the app to its luminous branch: from the repo root,
  `git subtree push --prefix=dreams/seize_the_day luminous <branch>`.
- Capture the look: `bash scripts/shoot-home.sh <dir>` → `docs/shots/<dir>.png`.
- If a change can't go green, **revert** it — don't leave the tree red or dirty.

## Overnight autonomous iteration
A 5-minute cron runs build cycles. Each tick follows `docs/tick-playbook.md`:
pick the next item from `docs/next-steps.md`, implement (optionally via subagents),
keep the loop working, run typecheck+test+build, update docs, commit on branch
`seize-the-day/overnight-build`. One narrow improvement per cycle. Never rewrite wholesale.
