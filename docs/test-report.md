# Test Report — 《今天别消失》

Updated each cycle. Reflects the latest run.

## Status (Cycle 13)

| Check | Command | Result |
| --- | --- | --- |
| Typecheck | `npm run typecheck` | ✅ clean |
| Unit + integration | `npm test` | ✅ 90/90 pass (11 files) |
| Production build | `npm run build` | ✅ 9 routes (incl. `/manifest.webmanifest`, dynamic `/seeds/[id]`) |
| Runtime smoke | `next start` + curl | ✅ `/`, `/now`, `/seeds`, `/seeds/[id]` → 200; manifest valid JSON; `/sw.js` → 200; icons → 200 |

New in Cycle 13: `contrast.test.ts` — 35 WCAG assertions (5 themes × 7 token pairs): primary/secondary ≥4.5, muted ≥3.0, on-accent ≥4.5.
Cycle 12: `a11y.test.tsx` — mood chips `aria-pressed`; steppers + AI toggle accessible labels.
Cycle 11: `store.test.ts` — `updateSettings` persists quiet hours + max reminders.
Cycle 10: `store.test.ts` — seed-detail edit persists; full sleep→wake→archive→restore lifecycle.
Cycle 9: `theme.test.tsx` — `AppProvider` applies `<html data-theme>`; `setTheme` updates DOM + persists.
Cycle 8: `copyLint.test.tsx` — copy dict + 6 rendered screens free of forbidden vocab.
Cycle 7: `nowFlow.test.tsx` — full core loop through the live store.
Cycle 6: `store.test.ts` — `updateTrace` rewrites + persists.

New in Cycle 4: `storage.test.ts` — late-night theme-offer dismissal token persists + clears.
Cycle 3: `scoring.test.ts` — outdoor+good-weather surfaces "坐一会野外"; at-computer surfaces a computer-bound creation seed.

## Coverage by area

- **scoring.test.ts** (11) — late-night never recommends downtown/hard learning; late-night surfaces & ranks rescue first; `isUnsafeLateNight` gate; tired→body/recovery; empty→recovery/connection/body/aesthetic; anxious avoids high-energy top; avoidant→tiny creation; lonely→connection; short free time→short action; serendipity yields variety; `recommend()` shape.
- **semanticTime.test.ts** (4) — hour→semantic mapping, weekend override, late-night boundaries.
- **seedParser.test.ts** (5) — outdoor/french/code wishes; always non-empty title + tiny minimum action; draft→active seed.
- **traceGenerator.test.ts** (5) — warm prefix; partial is positive and never shaming; skipped gentle; date/partial tagging.
- **storage.test.ts** (6) — persist/reload, defaults merge, theme store, clearAll, corrupt-JSON resilience.

## Known gaps (to add later)

- No component/integration test that drives the full Now flow through the store (jsdom + Testing Library available).
- No test asserting theme `data-theme` is applied to `documentElement`.
- No Playwright e2e yet (optional per brief).
- No copy-lint test asserting forbidden todo-app vocabulary is absent from rendered screens.
