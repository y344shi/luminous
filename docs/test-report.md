# Test Report — 《今天别消失》

Updated each cycle. Reflects the latest run.

## Status (Cycle 3)

| Check | Command | Result |
| --- | --- | --- |
| Typecheck | `npm run typecheck` | ✅ clean |
| Unit tests | `npm test` | ✅ 33/33 pass (5 files) |
| Production build | `npm run build` | ✅ 8 routes (incl. `/manifest.webmanifest`) |
| Runtime smoke | `next start` + curl | ✅ `/`, `/now`, `/seeds` → 200; manifest valid JSON; `/sw.js` → 200; icons → 200 |

New in Cycle 3: `scoring.test.ts` — outdoor+good-weather surfaces "坐一会野外"; at-computer surfaces a computer-bound creation seed.

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
