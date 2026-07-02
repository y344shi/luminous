# Overnight session — "aware" (2026-06-30 night)

Branch **`ios-aware`** in worktree `/Users/y344shi/Desktop/luminous/wt-aware`
(base: `macos` @ `717995c`). Your live Xcode copy and `wt-macos` were never touched.
Plan: `~/.claude/plans/modular-sauteeing-rabbit.md` · rationale: `ios/VISION-AUDIT.md`.

## Decisions taken on your behalf (you were AFK — reverse freely)

1. **"Database for multi user" = SwiftData local multi-profile**, schema
   CloudKit-sync-ready (all-default properties, no uniques, no relationships).
   NOT a cloud backend: real CloudKit sync + accounts needs the **paid** dev
   program, and `docs/database-plan.md` warns against blocking the core loop on
   infra. Multiple local "gardens" (profiles) are switchable in Settings.
2. **Old UserDefaults data is dual-written, never deleted** — reverting Store.swift
   restores everything. Watch stays on UserDefaults (`#if os(watchOS)`).
3. **Notifications are wired but default OFF** (`nudgesEnabled=false`), hard-gated
   by quietHours + maxRemindersPerDay + the late-night rule. Nothing pings you
   until you flip the toggle.
4. All LLM features follow the LearningMerge pattern: `@Generable` output +
   deterministic fallback + forbidden-words post-filter. Hard gates stay in code.

## Cycle log

| cycle | what | state |
| --- | --- | --- |
| C0 | worktree · SensorClassifiers split · SwiftPM test harness (`swift test`) | in progress |
| C1 | SwiftData multi-profile DB + migration + garden switcher | — |
| C2 | event log + foreground sensing cadence + rhythm histograms | — |
| C3 | LLM seed parser (fallback = keyword) + sensed signals into NowView | — |
| C4 | learned places: home/work from grid-cell frequency | — |
| C5 | proactive nearby scout → place-born shooting stars | — |
| C6 | recurrence historyBonus + fit-learning dampener + stable serendipity | — |
| C7 | mentality estimate (clamped ±0.2 term, never a label) | — |
| C8 | WishExecutor protocol + ReviewQuiz/CreationSpark/ConnectionDraft/RecoveryBreath + PursuitMerge | — |
| C9 | notification pipeline (default OFF) + quiet-hours UI | — |
| C10 | reason-writer + LLM suggestions (filtered, fallback) | — |
| C11 | weekly review paragraph | — |
| C12 | wrap: builds ×3 platforms, shots, this doc finished | — |

## Advice / questions for the morning

- (accumulates during the night)
