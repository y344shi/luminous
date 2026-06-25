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

---

## Cycle 5: Richer empty states + Now→trace bloom

What changed:
- `EmptyState` now supports an optional `icon` (emoji in a softly **pulsing** mark) and an optional `action` (an invitation link, never a command). Backward compatible.
- Wired warmer empties: Garden → 🌱 "种下第一个愿望"; Trace journal → 🪵 "现在别消失"; Now (no opportunities) → 🍃 "去种一个新愿望" (replaced the bare button).
- Added two CSS animations: `tdd-bloom` (the trace card now settles in with a one-time soft glow — the emotional payoff) and `tdd-pulse` (keeps blank screens alive). Both respect `prefers-reduced-motion`.

Why:
- Empty screens and the trace reveal carry the most feeling. Per the brief, blank states should invite (not judge) and the trace is where "今天没有消失" should land gently.

What was tested:
- `npm run typecheck` clean; `npm test` → 34/34; `npm run build` green.

What still feels wrong / not done yet:
- Bloom plays once on mount; navigating away and back replays it (acceptable).
- Could stagger the trace text fade after the card blooms for extra grace.

Next:
- Quality: integration test driving the full Now flow via the store; copy-lint test for forbidden vocabulary.

---

## Cycle 6: Self-written traces (your own words)

What changed:
- After a completion/partial, the trace step now offers a quiet "改成自己的话" link. Tapping it swaps the bloom card for a textarea prefilled with the generated sentence; "就这样" saves the user's own words.
- New `store.updateTrace(id, patch)` persists the edit; `NowFlow` tracks `savedTraceId` + edit draft state.
- New copy under `copy.traces` (edit / editSave / editPlaceholder).
- First `tests/store.test.ts` (2 tests): updateTrace rewrites + persists; leaves siblings untouched.

Why:
- The trace is the user's record of being in their own life — they should be able to phrase it themselves. Generated text is a gift, not a verdict. Editing is offered only when there is a saved trace (not for skipped/later).

What was tested:
- `npm run typecheck` clean; `npm test` → 36/36 (6 files); `npm run build` green.

What still feels wrong / not done yet:
- Can only edit the just-created trace from the Now flow; editing past traces from `/traces` is not yet possible.
- This clears the entire "High value, low risk" backlog section.

Next:
- Quality section: copy-lint test (forbidden vocab) and/or a Now-flow integration test; then product depth (seed detail page).

---

## Cycle 7: Now-flow integration test (core loop, end to end)

What changed:
- New `tests/nowFlow.test.tsx` renders the real `NowFlow` with Testing Library (jsdom), mocking `next/navigation`, and drives the whole loop through the live store:
  1. mood + energy → recommend → opportunity card → 完成了 → a `今天没有消失…` trace is created & persisted (partial=false).
  2. partial path → trace created with partial=true and **never** shaming (`/失败|浪费|没用/` absent).
  3. skipped path → **no** trace created, gentle "愿望还在" message shown.

Why:
- Unit tests covered each piece; nothing yet proved the actual wired UI loop. This is the brief's #1 invariant ("the core loop must never break") now guarded by a test that exercises components + store together.

What was tested:
- `npm run typecheck` clean; `npm test` → 39/39 (7 files); `npm run build` green.

What still feels wrong / not done yet:
- Asserts on text via `.toBeTruthy()` (no jest-dom matchers) — adequate, slightly verbose.
- Doesn't yet exercise the self-written-trace edit path or late-night gating in the UI.

Next:
- Copy-lint test (forbidden vocabulary across copy + rendered screens); then `data-theme` persistence test; then product depth.

---

## Cycle 8: Copy-lint test (tone guard)

What changed:
- New `tests/copyLint.test.tsx`: (1) recursively scans the whole `copy` dictionary for forbidden vocabulary; (2) renders Home, Seed garden, Trace journal, Settings, Now flow, and Add seed and asserts no forbidden word appears in visible text.
- Refined `forbiddenWords`: dropped the bare word 任务 (the app *intentionally* says "这些不是任务" to contrast with todo apps) and instead bans todo **framing/mechanics** (待办, 任务列表, 完成任务, todo, deadline, overdue, 优先级, 完成率, streak, 打卡) and **shaming** (失败, you must/failed). See decision D11.

Why:
- Tone is the product. A lint that fires when our own voice drifts toward todo-app/shaming language protects the soul of the app across future edits — including edits made by later autonomous ticks.

What was tested:
- `npm test` → 46/46 (8 files); `npm run typecheck` clean; `npm run build` green.
- The lint genuinely fired first (on a naive 任务 match), which drove the more precise forbidden list.

What still feels wrong / not done yet:
- Forbidden list is curated, not exhaustive; extend as new copy lands.
- Rendered-screen scan covers the main screens but not every transient sub-state (e.g. completion sheet, draft preview).

Next:
- `data-theme` applied + persisted test; then product depth (seed detail page) or accessibility pass.

---

## Cycle 9: Theme application + persistence test

What changed:
- New `tests/theme.test.tsx` (3 tests) covering the theme system end to end:
  1. `AppProvider` sets `<html data-theme>` to the default (`warm_paper`) after hydration.
  2. `store.setTheme("soft_ritual")` updates `<html data-theme>` **and** writes to storage (both `tdd.theme` and settings).
  3. A theme persisted before mount is restored on hydrate and applied to the DOM.

Why:
- Themes are a headline feature (5 of them) and the switch must survive reloads. Nothing tested the `AppProvider` ↔ store ↔ storage ↔ DOM wiring; now the contract is locked.

What was tested:
- `npm test` → 49/49 (9 files); `npm run typecheck` clean; `npm run build` green.
- Used `waitFor`/`act` to let `AppProvider`'s hydration + theme effects settle.

What still feels wrong / not done yet:
- Doesn't assert the actual CSS variable values resolve (jsdom doesn't apply stylesheets); the `[data-theme]` attribute is the contract we can verify.
- This clears all four testable Quality items; only the accessibility pass remains in that section.

Next:
- Product depth: seed detail page `/seeds/[id]` (edit / sleep / archive), or the Settings quiet-hours + max-reminders UI; or the accessibility pass.

---

## Cycle 10: Seed detail page (tend the garden)

What changed:
- New dynamic route `app/seeds/[id]/page.tsx` (awaits the Next 16 Promise `params`) rendering a client `SeedDetail`.
- `SeedDetail` lets you gently tend a wish: edit its **title** + **minimum action** (Save is disabled until something changes), and move it through soft lifecycle states — **让它先睡一会 / 唤醒它 / 轻轻收起来 / 放回花园**. Tone stays caring, never task-management.
- Seed cards in the garden are now tappable (wrapped in `Link`, subtle press scale).
- Graceful "这个愿望好像已经不在花园里了" state for unknown/archived ids.
- New copy under `copy.seedDetail`; 3 new store tests (edit persists; full sleep→wake→archive→restore lifecycle).

Why:
- The garden was read-only. Wishes evolve — you refine them, let them rest, or quietly retire them. This gives the user agency over their garden without importing todo-app mechanics (no delete-with-prejudice, no overdue; archived seeds just leave the garden softly).

What was tested:
- `npm run typecheck` clean; `npm test` → 51/51 (9 files); `npm run build` green (`/seeds/[id]` dynamic).
- Runtime smoke: `/seeds/seed_test123` and `/seeds` both 200.

What still feels wrong / not done yet:
- Editing only title + minimum action; doesn't re-run the parser to re-derive categories/energy/time.
- No confirm on archive (it's reversible via 放回花园, so low-stakes — intentional).

Next:
- Settings quiet-hours + max-reminders UI (model exists), or the accessibility pass.

---

## Cycle 11: Settings — quiet-hours UI

What changed:
- Added a "安静时段" section to `SettingsPanel`: two hour pickers (从 / 到, 00:00–23:00) bound to `quietHoursStart` / `quietHoursEnd`, with the line "这段时间它完全不打扰你。" (The max-reminders stepper already shipped in Cycle 1.)
- New `HourSelect` helper + copy under `copy.settings` (quietHelp/quietFrom/quietTo).
- 1 new store test: `updateSettings` persists quiet hours + max reminders.

Why:
- The privacy/quiet model existed but was invisible — the user couldn't set the window in which the app promises silence. This is core to the "it shouldn't nag you" contract.

What was tested:
- `npm run typecheck` clean; `npm test` → 52/52 (9 files); `npm run build` green.

What still feels wrong / not done yet:
- **Settings are stored & editable but not yet enforced** — there are no notifications to gate, so nothing reads quiet-hours/max-reminders. Added an explicit follow-up item (`isQuietNow` helper + reminder budget) to wire this up once local notifications land.

Next:
- Accessibility pass (focus states, aria labels, contrast across themes), or extract `packages/core`/`packages/design` ahead of iOS.

---

## Cycle 12: Accessibility pass (focus + ARIA)

What changed:
- Global keyboard `:focus-visible` ring (2px accent, offset) that shows for keyboard users only; pointer focus stays clean. Theme-aware via `--accent`.
- Bottom nav: `aria-label="主导航"`, `aria-current="page"` on the active tab, `aria-hidden` on its decorative dot.
- Selectable chips (mood/energy/free/location) now expose `aria-pressed`; the 天气不错 `ToggleChip` already did.
- Icon-only reminder steppers got accessible names ("增加/减少每天契机次数").
- New `tests/a11y.test.tsx` (3): mood chip toggles `aria-pressed`; steppers + AI-toggle expose accessible labels.

Why:
- The app should be usable one-handed *and* by keyboard/screen-reader users. Focus visibility and accurate state/labels are the highest-leverage a11y wins and cost nothing visually for pointer users.

What was tested:
- `npm run typecheck` clean; `npm test` → 55/55 (10 files); `npm run build` green.

What still feels wrong / not done yet:
- Per-theme **contrast** wasn't formally audited (esp. `--text-muted` on `--surface-soft`); jsdom can't measure it. Flagged for a deeper manual/tooling pass.
- No skip-link / landmark `<main>` aria beyond the existing structure.

Next:
- Platform: extract `packages/core` + `packages/design` ahead of iOS, or a per-theme contrast audit.

---

## Cycle 13: Per-theme contrast audit + token tuning (WCAG)

What changed:
- Measured every text/bg token pair across all 5 themes. Found widespread failures: `textMuted` 2.0–2.9 (target ≥3.0), several `textSecondary`-on-surfaceSoft < 4.5, and the **primary button label** failing badly (light text on muted accents — dusk_garden 2.11).
- Tuned tokens without changing the brief's accent palette: darkened `textSecondary` + `textMuted` in the 4 light themes (lightened muted slightly in soft_ritual), and added a new `--on-accent` token (a dark foreground) so the primary button label reads on the accent fill in every theme. `SoftButton` primary now uses `--on-accent`.
- Kept `globals.css` (runtime) and `themes.ts` (switcher/test source) in sync; added `onAccent` to `ThemeTokens` + `themeToCssVars`.
- New `tests/contrast.test.ts`: 35 assertions (5 themes × 7 pairs) — textPrimary/secondary ≥4.5, muted ≥3.0, on-accent ≥4.5. Permanent guard against future token drift.

Why:
- Readability is accessibility. The audit found real problems a user would feel — especially an unreadable primary CTA in dusk_garden. Solving via `--on-accent` (dark label) preserves each theme's specified accent color.

What was tested:
- `npm test` → 90/90 (11 files, +35 contrast); `npm run typecheck` clean; `npm run build` green. Copy-lint still passes (dark button text introduces no forbidden words).

What still feels wrong / not done yet:
- Accent used as *small text* (active nav label, links) is still < 4.5 on light surfaces — logged a follow-up for an `--accent-text` variant.
- Decorative borders/accent-soft fills weren't audited (non-text).

Next:
- `--accent-text` for accent-sized text, or extract `packages/core` + `packages/design` ahead of iOS.

---

## Cycle 14: `--accent-text` token (legible accent-colored text)

What changed:
- Added a per-theme `--accent-text` token — a darker accent reserved for accent-COLORED text (active bottom-nav label, the ThemeSwitcher active dot), while `--accent` stays vivid for fills/dots/focus ring.
- Solved values to clear AA on both surface and background in every theme (dusk darkened to #7A5822 for margin; soft_ritual keeps its amber since it sits on dark).
- Updated `BottomNav` active label + `ThemeSwitcher` dot to `--accent-text`; synced `globals.css`, `themes.ts` (type + objects + `themeToCssVars`).
- Extended `contrast.test.ts` with `accentText` on surface + background (now 50 contrast assertions; 100 tests total).

Why:
- Finishes the contrast story from Cycle 13: accent-as-text was the one remaining < 4.5 case. Separating "accent as fill" from "accent as text" is the standard, clean fix and keeps the vivid brand color for fills.

What was tested:
- `npm test` → 100/100 (11 files); `npm run typecheck` clean; `npm run build` green.

What still feels wrong / not done yet:
- The contrast guard covers text/accent roles; decorative borders and accent-soft fills remain unaudited (low risk).

Next:
- Platform: extract `packages/core` + `packages/design` ahead of iOS, or product depth (real-AI parser scaffold behind aiMode, server-side, coarse input only).

---

## Cycle 15: Real-AI parser seam (server route + safe fallback)

What changed:
- New isolation layer `lib/aiParser.ts`: a single `parseSeed(text, mode)` seam. `mock` → local rule parser (default, offline). `real` → POST `/api/seeds/parse`, with **any** failure falling back to `parseSeedMock` so Add can never break.
- New server route `app/api/seeds/parse/route.ts` (nodejs runtime): validates input (400 on empty/invalid JSON, 413 on >500 chars — a coarse-input guard), reads no client key, sends nothing but the wish text, and returns the local parse with `source: mock | ai-pending`. The live model call is a documented, `ANTHROPIC_API_KEY`-gated TODO (can't be exercised without a key here).
- `AddSeedFlow` now calls the seam based on `settings.aiMode` with a soft "正在接住……" state; default (mock) UX is unchanged and fully offline.
- New `tests/apiParse.test.ts` (4): valid draft, 400 empty, 400 bad JSON, 413 over-long.

Why:
- The brief wants the AI parser *isolated*, key-free, and coarse-input-only, with a "real AI mode". This establishes that seam end to end and safely, without a network dependency or any secret — and keeps the core loop intact when offline or when the route fails.

What was tested:
- `npm run typecheck` clean; `npm test` → 104/104 (12 files); `npm run build` green (`/api/seeds/parse` dynamic).

What still feels wrong / not done yet:
- No live model call yet (gated on a key absent from this env) — logged as an explicit follow-up.
- `parseSeed` real-path fetch isn't unit-tested (no server in jsdom); the route handler itself is tested directly.

Next:
- `isQuietNow` + reminder budget helper, or extract `packages/core`/`packages/design`, or wire the live model call when a key exists.
