# Architecture — 《今天别消失》

## Stack
- Next.js 16 (App Router) · React 19 · TypeScript · Tailwind v4 · Zustand · Vitest (jsdom).
- Persistence: `localStorage` (Phase 1). Prisma/Postgres planned (see `database-plan.md`).
- All logic runs locally; no network, no API keys.

## Layering
```
app/                 routes (server components shells) → render client feature components
components/          presentational + client interactive UI
  design/            SoftButton, BreathingCard, EmptyState, PageHeader, ThemeSwitcher
  layout/            AppShell, BottomNav
  seed/              AddSeedFlow, SeedCard, SeedGarden, RecentSeeds
  opportunity/       NowFlow (orchestrator), OpportunityCard
  context/           Pickers (mood/energy/free-time chips)
  trace/             TraceJournal, TraceCard, TodayTracePreview
  settings/          SettingsPanel
  AppProvider.tsx    hydrates store + syncs <html data-theme>
lib/                 framework-free domain logic (the "core" package candidate)
  types.ts           domain types
  scoring.ts         recommender (pure, testable, rng-injectable)
  seedParser.ts      mock NL → SeedDraft (swap point for real AI)
  traceGenerator.ts  completion → DailyTrace
  semanticTime.ts    hour → SemanticTime, late-night detection
  context.ts         build ContextSnapshot from minimal inputs
  storage.ts         SSR-safe localStorage adapter
  store.ts           Zustand store (the only stateful glue)
  themes.ts copy.ts categoryMeta.ts mockSeeds.ts utils.ts
tests/               Vitest unit tests + helpers
```

## Data flow (the core loop)
1. **Add:** `/add` → `AddSeedFlow` → `parseSeedMock(text)` → `SeedDraft` preview → `draftToSeed` → `store.addSeed` → `storage.saveSeeds`.
2. **Now:** `/now` → `NowFlow` collects mood/energy/free-time → `buildContext` → `recommend(seeds, ctx)` → top 3 `Opportunity`.
3. **Complete:** user picks one → completed/partial/skipped → `buildTrace` → `store.addTrace` (completed seed → status `sleeping`).
4. **Trace:** `/traces` + Home preview read `store.traces`.

## Key invariants
- `lib/*` is pure and import-free of React/Next, so it can become `packages/core` for the iOS/React Native build (see `ios-roadmap.md`).
- Scoring accepts an injectable `rng` for deterministic tests; serendipity is the only randomness.
- Late-night safety is enforced in `rankSeeds` (hard filter) before scoring matters.
- Store guards every persisted write through `storage`, which is a no-op on the server.

## Theming
CSS variables per `[data-theme="…"]` block in `globals.css`; `AppProvider` sets `documentElement[data-theme]` from the store; switching is instant and layout-invariant.
