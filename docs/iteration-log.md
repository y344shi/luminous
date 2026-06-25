# Iteration Log — 《今天别消失》

A running journal of build cycles. Newest at the bottom.

---

## Cycle 1: Foundation + full core loop (web MVP)

What changed:
- Set up Linux Node v22.14.0 (the env had only Windows node) and scaffolded Next.js 16 (App Router) + React 19 + Tailwind v4 + TypeScript.
- Added domain layer in `lib/`: `types.ts`, `themes.ts` (5 themes), `copy.ts`, `utils.ts`, `semanticTime.ts`, `context.ts`, `mockSeeds.ts`, `categoryMeta.ts`.
- Built the recommender: `scoring.ts` (weighted fit + mood shaping + late-night safety gate + trigger-condition bonus) and a mock `seedParser.ts`.
- Built `traceGenerator.ts` (warm, non-shaming traces; partial counts).
- Persistence: `storage.ts` (SSR-safe localStorage) + a Zustand `store.ts` with first-run mock garden seeding.
- UI: design system (`SoftButton`, `BreathingCard`, `EmptyState`, `PageHeader`), layout (`AppShell`, `BottomNav`), theme system applied via `data-theme` + CSS vars, `ThemeSwitcher`.
- Pages: Home `/`, Add `/add`, Garden `/seeds`, Now `/now` (the full flow), Traces `/traces`, Settings `/settings`.
- Tests: 31 Vitest tests across scoring, semanticTime, seedParser, traceGenerator, storage. All pass.

Why:
- The brief's #1 priority is a living core loop (Add Seed → Now Opportunity → Complete/Partial → Daily Trace). Everything here serves that loop end-to-end before any polish.

What was tested:
- `npm run typecheck` clean.
- `npm test` → 31/31 pass.
- `npm run build` → all 7 routes compile (static).
- Runtime smoke: `next start`, `/`, `/now`, `/seeds` all return 200; home renders “现在别消失”.

What still feels wrong / not done yet:
- Now flow uses `isAtComputer: true` as a hard assumption; should read real device context.
- No location/weather pickers yet (brief lists `LocationHintPicker`); recommendation can't yet use them from the UI.
- Quiet-hours setting exists in the model but no UI control yet.
- No PWA manifest yet.
- Themes are wired but only lightly visually differentiated beyond color; typography is uniform.

Next:
- Cron-driven agentic iteration: polish themes, add location/weather context to Now, PWA manifest, richer empty states, accessibility pass, and a Now→trace animation.
