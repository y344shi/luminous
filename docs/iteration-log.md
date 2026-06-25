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

---

## Cycle 2: PWA — installable, offline-capable shell

What changed:
- Added `app/manifest.ts` → served at `/manifest.webmanifest` (name, standalone, portrait, warm-paper theme color, categories).
- Generated on-brand PNG icons with `sharp` (192, 512, maskable-512, apple-touch-180) into `public/icons/` — a sage sprout under a soft dusk light on warm paper.
- Added `public/sw.js`: network-first for navigations (offline falls back to cached shell), cache-first for `/icons/` + `/_next/static/`. Fails soft; caches nothing sensitive.
- `ServiceWorkerRegister` client component registers the SW in production only (offline is an enhancement, never a blocker).
- Wired `manifest`, `icons`, and apple-touch into root metadata.

Why:
- First "high value, low risk" item in next-steps. Makes the app installable to the home screen and openable offline — the natural bridge toward the iOS target, with zero new runtime deps.

What was tested:
- `npm run typecheck` clean; `npm test` → 31/31; `npm run build` → `/manifest.webmanifest` now a route, all compile.
- Runtime smoke (`next start`): manifest serves valid JSON; `/sw.js` → 200 `application/javascript`; `/icons/icon-512.png` → 200.

What still feels wrong / not done yet:
- SW registers only in prod, so dev never exercises offline — acceptable; verify on a deployed/`next start` instance.
- No "add to home screen" hint UI; relying on browser/OS affordance.
- Icons are abstract; may want a more distinctive mark later.

Next:
- Now-screen one-tap context chips (我在外面 / 天气不错 / 在电脑前) feeding locationHint + weather; then auto-offer soft_ritual at late night.

---

## Cycle 3: Now-screen place & weather context

What changed:
- Added an optional "你现在在哪？（可跳过）" location chip group to the Now flow (在家 / 电脑前 / 在外面 / 市中心 / 路上); tapping the selected chip again clears it.
- A conditional "外面天气不错" toggle appears only when location is outdoor/downtown, feeding `isOutdoorWeatherGood`.
- `NowFlow` now passes `locationHint`, weather, and derives `isAtComputer` from the location — replacing the hardcoded `isAtComputer: true` assumption (resolves open-question #3 partially).
- New `ToggleChip` + `locationOptions` in `Pickers.tsx`.
- 2 new scoring tests: outdoor+good-weather surfaces "坐一会野外" first; at-computer lets a computer-bound creation seed rank.

Why:
- Location and weather already drove `triggerBonus`/`locationFit` in scoring, but the UI had no way to supply them — so the most context-aware recommendations were unreachable. This connects the existing engine to real user input with minimal, skippable friction (ISFP-safe).

What was tested:
- `npm run typecheck` clean; `npm test` → 33/33; `npm run build` green.

What still feels wrong / not done yet:
- Location is self-reported only; no geolocation (intentional for now — coarse, private).
- Weather toggle is manual; a future coarse weather API could prefill it.

Next:
- Auto-offer `soft_ritual` theme at late night (non-forcing).

---

## Cycle 4: Gentle late-night theme offer

What changed:
- New `LateNightThemeOffer` card on Home: at late night (and only if the theme isn't already `soft_ritual`), it softly asks "要不要把灯光调暗一点，换上睡前的样子？" with one tap to accept and one to dismiss.
- Non-forcing + non-nagging: dismissal is remembered for the rest of tonight via a per-date token (`storage.{load,save}RitualOfferDismissed`); accepting just calls `setTheme("soft_ritual")`.
- Time is computed in `useEffect` (client-only) to avoid SSR/client hydration mismatch.
- New copy under `copy.lateNight` (offer/accept/dismiss). 1 new storage test (34/34).

Why:
- Soft Ritual is purpose-built for the late-night stop-loss moment (warm dark, candle amber). Offering — never forcing — it honors the brief's late-night care and ISFP autonomy ("可以跳过").

What was tested:
- `npm run typecheck` clean; `npm test` → 34/34; `npm run build` green.

What still feels wrong / not done yet:
- Offer only appears on Home; could also surface within the Now late-night card.
- "Tonight" is approximated by calendar date, so a dismissal before midnight won't carry past 00:00 — acceptable.

Next:
- Richer empty states + a gentle Now→trace transition animation.
