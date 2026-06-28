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

---

## Cycle 16: Quiet-hours logic + reminder budget (+ live indicator)

What changed:
- New pure `lib/reminders.ts`: `isQuietNow(settings, now)` (hour-granular, handles windows that wrap past midnight; `start === end` = no quiet), `remindersRemaining(settings, sentToday)` (never negative), and `canRemindNow(...)` = not-quiet AND budget-left.
- Gave it a real consumer now (not just future notifications): the Settings quiet section shows a live line — "现在正处在安静时段，它不会主动打扰你。" / "现在不在安静时段。" — computed client-side to avoid hydration mismatch. The quiet-hours setting now visibly *means* something.
- New `tests/reminders.test.ts` (5): wrap-around + same-day + degenerate windows; budget clamping; the combined gate.

Why:
- Cycle 11 added the quiet-hours UI but nothing read it. This turns the stored setting into real, tested logic and shows the user its current effect — closing the loop short of actual notifications (which don't exist yet).

What was tested:
- `npm run typecheck` clean; `npm test` → 109/109 (13 files); `npm run build` green.

What still feels wrong / not done yet:
- `canRemindNow` has no production caller yet — there are still no reminders/notifications to gate. It's ready and tested for when PWA/local notifications land.

Next:
- Extract `packages/core` + `packages/design` ahead of iOS, or a Prisma schema (Phase 2), or the key-gated live model call.

---

## Cycle 17: Phase-2 schema + validated (de)serialization seam

What changed:
- Added `prisma/schema.prisma` (User / Seed / Opportunity / DailyTrace) as an inert Phase-2 record — enums kept as strings to mirror `lib/types.ts`, arrays as Postgres `String[]`, plus `partial` on traces and helpful indexes. Not installed/wired (stays localStorage-first).
- Added `lib/serialize.ts`: a DB-agnostic `deserializeSeed/Trace(+s)` boundary that **validates + coerces** unknown records (bad enums → safe defaults, malformed → dropped) and `serialize` is plain JSON. This is the seam a Prisma/Supabase adapter will sit behind.
- Hardened `storage.loadSeeds/loadTraces` to run loaded data through the validators — a corrupt or partial localStorage entry can no longer crash the garden/journal.
- New `tests/serialize.test.ts` (7): round-trips, drops id/title/date-less records, coerces bad enum/array/number fields, filters lists.

Why:
- The brief's Phase-2 DB shouldn't block the MVP, but the *boundary* should exist so persistence can swap without touching domain types — and validating on load is a real robustness win today (resilience to schema drift / corruption).

What was tested:
- `npm run typecheck` clean; `npm test` → 116/116 (14 files); `npm run build` green. The existing "survives corrupt JSON" storage test still passes.

What still feels wrong / not done yet:
- No live DB connection (no prisma install / DATABASE_URL) — deliberately deferred; logged as a follow-up.
- `Opportunity` isn't persisted client-side yet (it's transient); the schema anticipates it.

Next:
- Extract `packages/core` + `packages/design` ahead of iOS, or wire the live model call, or a Cycle-10 five-lens self-review (`docs/morning-review.md`).

---

## Cycle 18: Five-lens self-review (morning review)

What changed:
- Wrote `docs/morning-review.md`: a genuine review through the brief's five lenses (product designer, ISFP user, tired 3AM user, technical maintainer, future iOS dev), grounded in the actual code (cites real findings, not platitudes).
- Fed the concrete findings back into `docs/next-steps.md` as a new prioritized "Polish" section (P1/P2).

Why:
- The three remaining backlog items are all infra-heavy and risky/blocked for a single green-keeping tick (monorepo split; live DB needs `DATABASE_URL`; model call needs a key). Per the playbook, the highest-value *safe* move was the mandated Cycle-10 self-review — it costs no risk and produces a better-prioritized backlog than forcing risky infra.

Real findings surfaced (now scheduled):
- **P1** `window.confirm` reset breaks the soft aesthetic — needs an in-app soft confirm.
- **P1** `globals.css` and `themes.ts` duplicate token values with no test asserting they match — silent-drift risk.
- **P2** raw `YYYY-MM-DD` trace dates; late-night theme offer absent on `/now`; Add textarea has no `<label>`; first-run mock garden unexplained; no CI; Now shows one opportunity at a time.

What was tested:
- Docs-only cycle. Confirmed state remains green: 116 tests, typecheck clean, build green (no code changed).

Next:
- Work the P1s from the review: in-app soft confirm, then the token-sync guard test.

---

## Cycle 19: In-app soft confirm (no more window.confirm)

What changed:
- New reusable `components/design/ConfirmSheet.tsx`: a themed bottom-sheet dialog (dim backdrop, `role="dialog"` + `aria-modal`, Escape cancels, focus lands on the safe Cancel action, safe-area padding).
- `SettingsPanel` data-reset now opens the soft sheet instead of the OS `window.confirm` — the one place the system UI was breaking the app's aesthetic (morning-review P1, lens: ISFP user).
- New copy under `copy.settings` (resetConfirmTitle/Yes/No).
- New `tests/confirmSheet.test.tsx` (3): cancel keeps data, confirm wipes traces + replants garden, and `window.confirm` is never called.

Why:
- Aesthetic consistency is part of the product's soul; a jarring native dialog at the destructive moment undermines the "gentle, never alarming" tone. A soft, reversible-feeling sheet fits.

What was tested:
- `npm run typecheck` clean; `npm test` → 119/119 (15 files); `npm run build` green.
- The reset-button text collides with its section title — fixed the test to query by role (a small reminder that label reuse needs role-based queries).

What still feels wrong / not done yet:
- `ConfirmSheet` is only used for reset; other irreversible-ish actions (none currently) could reuse it.

Next:
- P1: token-sync guard test (`globals.css` `[data-theme]` ↔ `themes.ts`), then the P2 polish items.

---

## Cycle 20: Token-sync guard test (globals.css ↔ themes.ts)

What changed:
- New `tests/tokenSync.test.ts`: reads `app/globals.css`, parses each `[data-theme="…"]` block's `--var: value;` declarations, and asserts they equal `themeToCssVars(name)` from `themes.ts` for every color token (—shadow-card excluded: per-theme in CSS, shared constant in TS). Also asserts every theme has a block.

Why:
- The maintainer lens (morning review, P1) flagged that runtime colors (`globals.css`) and the TS token source (`themes.ts`, used by the switcher swatches + the contrast test) duplicate values with nothing asserting they match — a silent-drift risk. If they diverge, the contrast test could pass while the actual app fails (or vice-versa). This closes that gap.

What was tested:
- `npm run typecheck` clean; `npm test` → 125/125 (16 files); `npm run build` green. (Fixed an `import.meta.url` file-scheme error under the vitest transform by reading via `process.cwd()`.)

What still feels wrong / not done yet:
- The two token sources still must be hand-edited together — the test only *catches* drift, it doesn't generate one from the other. A future build step could generate `globals.css` blocks from `themes.ts` (single source of truth).

Next:
- P2 polish: human trace dates, `/now` late-night offer, Add textarea label, first-run garden note, CI, opportunity peeks.

---

## Cycle 21: Human trace dates

What changed:
- New pure `friendlyDate(dateKey, today?)` in `lib/utils.ts`: 今天 / 昨天 / 前天, else "M月D日", with the year prepended only when it differs from today. `today` is injectable for deterministic tests; malformed input passes through unchanged.
- `TraceJournal` now renders section headers via `friendlyDate(date)` instead of raw `YYYY-MM-DD`. It's a client-only component (guards on `hydrated`), so computing "today" at render causes no SSR mismatch.
- New `tests/friendlyDate.test.ts` (5): relative labels, same-year vs cross-year formatting, future-date guard, malformed passthrough.

Why:
- Morning-review P2 (ISFP lens): raw ISO dates read like a log, not a journal of being present. "今天 / 昨天" is warmer and matches the product's voice.

What was tested:
- `npm run typecheck` clean; `npm test` → 130/130 (17 files); `npm run build` green.

What still feels wrong / not done yet:
- "Today" is computed once per render; a journal left open across midnight won't relabel until navigation — negligible.

Next:
- P2: surface late-night theme offer on `/now`; Add textarea `<label>`; first-run garden note; CI workflow.

---

## Cycle 22: Late-night theme offer on /now

What changed:
- Rendered the existing `LateNightThemeOffer` on the Now page (above `NowFlow`), so a 3AM user who deep-links straight to `/now` — where the rescue copy already lives — also gets the gentle Soft Ritual offer, not just on Home.
- New `tests/lateNightOffer.test.tsx` (2): with `vi.setSystemTime`, the offer appears at 02:00 (theme ≠ soft_ritual) and is absent at 15:00.

Why:
- Morning-review P2 (tired-3AM lens): the dim-the-lights offer was Home-only; the Now screen is exactly where a late-night user lands and most needs it.

What was tested:
- `npm run typecheck` clean; `npm test` → 132/132 (18 files); `npm run build` green.
- Note: `waitFor` stalls under `vi.useFakeTimers()`; since RTL's `render` flushes effects in `act`, the assertions run synchronously after render instead.

What still feels wrong / not done yet:
- The offer now renders on both Home and Now; if both are mounted (they aren't simultaneously) it'd double — not a real case with route-based pages.

Next:
- P2: Add textarea `<label>` (a11y); first-run garden note; CI workflow; opportunity peeks.

---

## Cycle 23: Form-label associations (a11y)

What changed:
- Add-seed textarea now has an associated `sr-only` `<label htmlFor="seed-input">` (`copy.add.inputLabel`) instead of relying on placeholder-only.
- Seed-detail title `<input>` and minimum-action `<textarea>` labels are now linked via `htmlFor`/`id` (they were visually present but not associated).
- Extended `a11y.test.tsx` (2): the add textarea and both seed-detail fields are reachable via `getByLabelText`.

Why:
- Morning-review P2 (a11y): placeholder text is not an accessible name; screen-reader users had no label for the primary "catch a wish" input. Same gap existed on the seed-detail fields — fixed together since it's one concern.

What was tested:
- `npm run typecheck` clean; `npm test` → 134/134 (18 files); `npm run build` green.

What still feels wrong / not done yet:
- Quiet-hours `HourSelect` already uses a wrapping `<label>` (implicit association) — fine.

Next:
- P2: first-run garden note (so it doesn't read as someone else's data); CI workflow; opportunity peeks.

---

## Cycle 24: First-run garden note

What changed:
- Tracked a `samplesPlanted` flag (store + `tdd.samplesPlanted` storage): set true when `hydrate` plants the first-run mock garden, cleared when the user adds their own wish (`addSeed`) or dismisses the note; reset to true on `resetAll`.
- New `GardenNote` on `/seeds` (above the garden): a gentle, dismissible "这些是几个示例愿望，先帮你感受一下。随时可以改成自己的，或者轻轻收起来。[知道了]".
- New copy under `copy.garden`; 3 store tests (hydrate flags it; adding a wish clears it; dismiss clears + persists).

Why:
- Morning-review P2 (product-designer lens): seven pre-seeded wishes the user didn't write can read as "someone else's data." Naming them as examples — and letting them vanish the moment the garden becomes the user's — builds trust without leaving the app empty on first open.

What was tested:
- `npm run typecheck` clean; `npm test` → 137/137 (18 files); `npm run build` green. Copy-lint still passes (new strings clean).

What still feels wrong / not done yet:
- The note is informational only; a one-tap "清空示例" could be offered, but archiving/editing per-seed already covers it and avoids a destructive shortcut.

Next:
- P2: CI workflow (typecheck + test + build), or opportunity "或者……" peeks on the Now screen.

---

## Cycle 25: Opportunity peeks ("或者，现在也可以：")

What changed:
- The Now "list" step still leads with one calm OpportunityCard, but now shows the *other* top recommendations as muted, tappable peek chips under "或者，现在也可以：". Tapping a peek makes it the active card (the previous one becomes a peek).
- Keeps the 换一个 cycle button too; the peeks just make the considered alternatives visible instead of hidden behind repeated taps.
- Extended `nowFlow.test.tsx`: peeks render with the mock garden, tapping a peek promotes it to the heading, and the start action stays available.

Why:
- Morning-review P2 (product-designer lens): showing one card at a time hid that the app weighed several options. A quiet "或者……" row reveals the breadth without overwhelming an ISFP user — still one clear primary action.

What was tested:
- `npm run typecheck` clean; `npm test` → 138/138 (18 files); `npm run build` green.

What still feels wrong / not done yet:
- Peeks show seed titles only (no minimum-action preview) — intentional, to keep the row light.

Next:
- This clears every morning-review P1/P2 item except the CI workflow (can't be exercised in this env). Remaining backlog is platform-scale: `packages/core`/`packages/design` extraction, live DB wiring, the key-gated live model call, CI.

---

## Cycle 26: CI workflow (typecheck + test + build)

What changed:
- Added `.github/workflows/seize-the-day-ci.yml` at the **monorepo root** (GitHub only reads workflows from the repo root, not from `dreams/seize_the_day/`). It is **path-scoped** to `dreams/seize_the_day/**`, so it never runs for the monorepo's other dreams.
- The job: checkout → setup-node 22 (npm cache keyed to the project lockfile) → `npm ci` → `npm run typecheck` → `npm test` → `npm run build`, all with `working-directory: dreams/seize_the_day`.
- Committed alongside `dreams/seize_the_day` (an explicit extra `git add` of the root workflow path, since it lives outside the usual project dir).

Why:
- Morning-review P2 (maintainer lens): every cycle's green-keeping was manual. This locks typecheck + 138 tests + build into automation for any push/PR touching the project — the natural home for the discipline this loop has followed by hand.

What was tested:
- The workflow YAML was validated (key presence + `yaml.safe_load`). It **cannot be executed in this environment** (no GitHub runner) — flagged honestly. The app itself stays green: 138 tests, build green.

What still feels wrong / not done yet:
- Unverified end-to-end until the branch is pushed to GitHub. The blast radius is bounded by the path filter.

Next:
- Only platform-scale items remain (packages extraction, live DB, key-gated model call). The next tick will likely run a fresh five-lens self-review to regenerate a sharp backlog, since the polish list is exhausted and the rest is large/blocked.

---

## Cycle 27: Core-purity guard (iOS-readiness precondition)

What changed:
- New `tests/corePurity.test.ts`: scans every `lib/*.ts` except the store glue (`store.ts`) and asserts none import from React / Next / Zustand or carry a `"use client"` directive. 16 assertions (15 core modules + a "we actually scanned ≥10" sanity check).

Why:
- The remaining platform items (packages split, live DB, key-gated model call) are all large or environment-blocked. The *safe, valuable* first step of the `packages/core` extraction is to lock the precondition it depends on: `lib/` must stay framework-free so it can become a shared RN/iOS package (ios-roadmap.md). Audited it (only `store.ts` touches Zustand/`"use client"`), then froze that invariant in a test so a future UI import into core logic fails CI instead of silently breaking the iOS path.

What was tested:
- `npm run typecheck` clean; `npm test` → 154/154 (19 files); `npm run build` green.

What still feels wrong / not done yet:
- The actual workspace lift (pnpm/npm workspaces, moving files, retargeting `@/` imports) is genuinely risky for a single green-keeping tick and is best done deliberately, not autonomously — left open with that note.

Next:
- Polish + safe-precondition work is exhausted; a fresh five-lens self-review (Cycle 28) to regenerate a sharp backlog, or pause on the remaining blocked/large items.

---

## Cycle 28: Self-review round 2 (regenerate backlog)

What changed:
- Appended a "Round 2" section to `docs/morning-review.md`: a fresh five-lens pass (plus an ownership/privacy lens) over the post-Cycle-27 app, grounded in real code checks (confirmed: no remembered mood/energy, no trace export, no onboarding, no per-trace delete).
- Added a "Polish (round 2)" section to `docs/next-steps.md` with the new findings, prioritized.

Why:
- The three open backlog items are all large or environment-blocked (workspace lift, live DB, key-gated model call). Forcing them in an autonomous green-keeping tick is the wrong risk. Round 1's review (Cycle 18) drove nine green cycles; a second review now — after the app materially changed — regenerates a safe, high-value backlog so the loop keeps making real progress instead of idling or churning.

New findings (now scheduled):
- **P2** Export/keep traces (the journal is the user's "year rings"; only reset exists today) — strongest new item.
- **P2** Remember last mood/energy in Now (fewer decisions for returning users).
- **P2** First-open intro card introducing the concept.
- **P3** Per-trace delete + journal size cap; optional recovery trace for "今天先这样".

What was tested:
- Docs-only. State stays green: 154 tests, typecheck clean, build green (no code changed).

Next:
- Implement the round-2 P2s, starting with trace export (pure formatter + copy action — safe and testable).

---

## Cycle 29: Export / keep your traces

What changed:
- New pure `lib/exportTraces.ts` → `formatTracesForExport(traces, today?)`: renders the journal as plain text — a titled keepsake grouped by human date (reusing `friendlyDate`), newest first, bullet lines; `""` when empty. Deterministic (today injectable), framework-free (passes the core-purity guard).
- New `TraceExport` client component on `/traces`: a "把你的痕迹存下来" button that copies the formatted journal to the clipboard ("已经复制下来了"); on clipboard failure it shows a gentle manual-copy hint. Hidden when there are no traces.
- New copy under `copy.traces`; new `exportTraces.test.ts` (5): empty, header+text, newest-first grouping, bullet/trailing-newline.

Why:
- Morning-review round 2 (ownership/privacy lens): the traces are the user's "year rings", yet the only data action was destructive reset. Letting them keep their real moments fits the product's soul and costs no privacy (it's their own data, client-side, no network).

What was tested:
- `npm run typecheck` clean; `npm test` → 159/159 (20 files); `npm run build` green. Core-purity + copy-lint still pass with the new module/strings.

What still feels wrong / not done yet:
- Copy-only (no file download) — simplest and works in the PWA; a `.txt` download could be added later.

Next:
- Round-2 P2: remember last mood/energy in the Now flow (persist + pre-select).

---

## Cycle 30: Remember last mood/energy in Now

What changed:
- Persist the last mood/energy chosen in the Now flow: new `tdd.lastPick` storage key + `LastPick` type, store state `lastPick` (loaded on hydrate), and a `rememberPick(mood, energy)` action called when the user runs a recommendation.
- `NowFlow` pre-selects the remembered mood/energy on mount (a `useEffect` that only fills a still-empty choice via `prev ?? …`, so it never overrides a fresh selection). A returning user can go straight to "看看现在适合做什么".
- Cleared on `resetAll`; included in `clearAll`'s key sweep.
- New tests: store `rememberPick` persists; `NowFlow` integration — remembered pick shows `aria-pressed` chips and is immediately ready.

Why:
- Morning-review round 2 (ISFP lens): the Now flow re-quizzed mood + energy every visit. Remembering removes two decisions for a returning user — fewer taps, less "being tested" — while still letting them change their mind.

What was tested:
- `npm run typecheck` clean; `npm test` → 161/161 (20 files); `npm run build` green.

What still feels wrong / not done yet:
- Pre-selects but doesn't auto-run; the user still taps "看看……" — intentional (state can change moment to moment).
- Free-time and location aren't remembered (more situational); deliberately left per-visit.

Next:
- Round-2 P2: first-open intro card introducing Seed / Trace / "别消失".

---

## Cycle 31: First-open intro card

What changed:
- New `IntroCard` on Home: a calm, one-time, dismissible card framing the idea — "把脑子里一闪而过的小愿望丢进来，它们会变成一颗颗种子。当你想做点什么，我帮你挑一个现在刚好合适的小动作。做了一点，也算——今天就留下一道痕迹。[开始吧]".
- Persisted `introSeen` flag (storage `tdd.introSeen` + store state, loaded on hydrate, set on dismiss, reset on `resetAll`).
- New copy `copy.intro`; tests: store lifecycle (default unseen → dismiss persists) + component (shows then disappears after 开始吧; hidden once seen).

Why:
- Morning-review round 2 (product-designer lens): new users met a pre-seeded garden with no framing of what a Seed/Trace is or why "别消失". One gentle card builds trust without a heavy onboarding flow — and it's dismissible, ISFP-respecting.

What was tested:
- `npm run typecheck` clean; `npm test` → 164/164 (21 files); `npm run build` green. Copy-lint + core-purity still pass.

What still feels wrong / not done yet:
- On a brand-new install the Home shows the intro and `/seeds` shows the samples note — two gentle explainers, but on different screens, so not crowded.

Next:
- Only P3s (per-trace delete + size cap; optional "今天先这样" recovery trace) and the blocked/large platform items remain. Next tick: a P3, or idle if nothing is safely worth it.

---

## Cycle 32: Per-trace delete (gentle) + journal size cap

What changed:
- `store.removeTrace(id)` deletes a single trace and persists; `addTrace` now caps the journal at 500 (drops oldest) so localStorage can't grow unbounded.
- `TraceCard` gains an optional, deliberately subtle "×" affordance (muted, low-opacity, `aria-label="擦掉这一条痕迹"`); `TraceJournal` owns the delete state and routes it through the existing soft `ConfirmSheet` ("擦掉这一条痕迹？ / 擦掉 / 留着") — never a native dialog.
- New copy under `copy.traces`; tests: store remove + cap; journal delete flow (confirm removes, cancel keeps).

Why:
- Morning-review round 2 (maintainer lens): the journal was append-only and unbounded with no tidy affordance. Kept the tone right — the traces are warm "year rings", so deletion is phrased as gently "擦掉" with a soft confirm, not a task-list ✕-with-prejudice, and stays opt-in/subtle so the journal still reads as a record, not a manager.

What was tested:
- `npm run typecheck` clean; `npm test` → 168/168 (22 files); `npm run build` green.

What still feels wrong / not done yet:
- No undo after delete (the soft confirm is the safety). The 500 cap is generous; could be configurable later.

Next:
- Last P3: optionally record a gentle recovery trace for "今天先这样" — a product-philosophy call; otherwise the actionable backlog is exhausted (only blocked/large platform items remain) and the loop should idle.

---

## Cycle 33: Optional rest trace for "今天先这样"

What changed:
- New `buildRestTrace()` in the trace generator: a recovery-category, non-shaming line "今天没有消失，因为你及时停下来了。".
- On the Now "今天先这样" (onLater) path, the trace screen now *offers* a one-tap "把「我今天选择了停下」记成一笔" button (only when nothing was saved and it's the later path — not the skipped path). Tapping records the rest trace (and it can then be reworded via the existing edit affordance).
- New copy `copy.now.recordRest`; decision **D14** documents the call; tests: generator (warm/recovery/non-shaming) + Now integration (later saves nothing by default, can record a rest trace).

Why:
- Morning-review round 2 (product-designer lens, P3): the brief (§17) treats stopping as a real act, but auto-logging every defer would turn "not now" into an obligation. Offering — not forcing — keeps the user in charge of whether resting counts today, true to the product's soul.

What was tested:
- `npm run typecheck` clean; `npm test` → 170/170 (22 files); `npm run build` green.

What still feels wrong / not done yet:
- Nothing outstanding for this item.

Next:
- The actionable backlog is now fully exhausted: only blocked/large platform items remain (workspace lift, live DB needing `DATABASE_URL`, key-gated model call). Per the playbook, with nothing safely worth doing, the next ticks should idle quietly rather than manufacture churn — or do another self-review if enough has changed to warrant one.

---

## Cycle 34: Wire the live model call (env-gated, fail-soft)

What changed:
- Reconsidered the "blocked" live-model item and found a safe path: the call uses the **global `fetch`** (no SDK dependency), reads `process.env.ANTHROPIC_API_KEY` server-side only, and is fully wrapped in try/catch with a **mock fallback** — so it's dormant here (no key) yet correct when a key is present.
- New pure `lib/seedAiPrompt.ts`: the system prompt (encodes the SeedDraft schema **and** the tone rules — tiny minimum action, no task/shame framing) and `parseModelDraft(raw, rawText)` — a validator that extracts JSON even from fenced/prose output, coerces bad enums to safe defaults, and rejects (→ mock) when title/minimumAction are missing.
- Route `/api/seeds/parse`: with a key, calls Claude Haiku 4.5 (`claude-haiku-4-5-20251001`) sending **only the wish text**; any failure → local parser. `source` is now `ai | mock`.
- New `seedAiPrompt.test.ts` (5) + updated `apiParse.test.ts`.

Why:
- The item was achievable without a key or a new dependency, and without risking the build: the live path never runs in this env, the mock fallback keeps every test green, and the response is validated by the same safety-net pattern as the rest of the app. Better than idling.

What was tested:
- `npm run typecheck` clean; `npm test` → 176/176 (23 files); `npm run build` green. Confirmed `ANTHROPIC_API_KEY` is unset → route returns `source: mock`. Core-purity still passes (the new module is framework-free).

What still feels wrong / not done yet:
- The real network path is **not runtime-tested** (no key here) — only the validator + the no-key fallback are. Flagged: verify once a key exists.

Next:
- Now only the genuinely large/blocked platform items remain (workspace lift — risky refactor; live DB — needs `DATABASE_URL`). Per the playbook, the loop should idle quietly unless the environment changes or new direction arrives.

---

## Steady state reached (Cycle 35 onward — idle)

The whole actionable backlog is done: the original 10-cycle plan, both five-lens
self-review rounds, and every P1/P2/P3. State: **34 cycles, 176 tests (23 files),
typecheck clean, build green**, full WCAG-AA contrast (guarded + sync-checked),
PWA-installable, framework-free core (enforced), live-AI parser wired (dormant
without a key), trace export/edit/delete, remembered context, first-open intro,
CI defined.

Only two items remain, both deliberately **not** suitable for an autonomous
green-keeping tick:
1. **Workspace lift** (`packages/core` + `packages/design`) — a high-churn monorepo
   refactor (workspaces config, moving files, retargeting `@/` imports). Its
   precondition is already enforced (Cycle 27 purity guard). Best done in a
   deliberate, supervised session, not by a 5-minute autonomous tick.
2. **Live DB wiring** — needs a real `DATABASE_URL` and a prisma install; the
   schema + `deserialize*` adapter boundary are already in place (Cycle 17).

Per the tick playbook ("if three consecutive ticks find nothing safe, idle
quietly"), the loop now idles: each tick re-checks the backlog and the env, runs
a green sanity check, and skips without manufacturing churn. It will resume real
work automatically if the environment changes (a `DATABASE_URL`/`ANTHROPIC_API_KEY`
appears) or new direction is given. To hand off either remaining item, a human
can green-light the workspace refactor or provide DB credentials.

### Loop concluded (after 3 idle ticks)

After three consecutive idle ticks with no environment change, the recurring
5-minute cron (`e7e4170e`) was cancelled to stop indefinite idle polling from
consuming tokens overnight. The overnight build is complete and at rest:
**34 cycles, 176 tests green, build green**, every brief Definition-of-Done item
plus both self-review rounds addressed. The two remaining items are explicitly
deferred by the brief itself (§32 "Do not start iOS tonight"; §35 "don't chase
database perfection before local MVP"). To continue later: re-create the cron, or
just ask — provide a `DATABASE_URL` / `ANTHROPIC_API_KEY`, or green-light the
`packages/*` workspace lift, and that work can proceed directly.

---

## Cycle 35: Proactive ambient home with floating bubbles (user request)

What changed:
- New `lib/ambient.ts` (pure): `guessLocation`, `ambientLabel` (周X · 时段 · 在哪),
  `buildAmbientContext` (mood=unknown), `isWorkday`. Senses time-of-day,
  weekday/weekend, and at-computer-vs-mobile with **no permission**.
- New `components/home/AmbientBubbles.tsx`: on opening Home it builds the ambient
  context and floats the top recommendations as gently drifting bubbles
  (`tdd-float-*`). Tapping a bubble opens a soft sheet → 完成了 / 做了一点 / 先放着,
  recording a trace inline (completed → seed sleeps; bubble pops). Includes a
  correctable location (reuses the location chips) and an **opt-in** geolocation
  movement sense (`watchPosition` speed → 路上). Everything stays on-device.
- Rendered on Home above "现在别消失" (the mood/energy flow stays for when you
  want to be specific).
- New copy under `copy.home`; float keyframes + reduced-motion guard.
- Tests: `ambient.test.ts` (8 — location guess, label incl. weekend time-of-day,
  context) + `ambientBubbles.test.tsx` (1 — senses moment + floats bubbles).

Why:
- User asked for opportunities to surface proactively — to auto-know whether
  they're home / moving, whether it's lunch or evening, weekday or not, and float
  a few bubbles on Home. This delivers the no-permission parts fully (time, day,
  device) and makes location/movement a correctable guess + opt-in sense, true to
  the brief's coarse-context, privacy-first rule (no GPS leaves the device).

What was tested:
- `npm run typecheck` clean; `npm test` → 186/186 (24 files); `npm run build` green.
- Verified live in the browser: Home showed "周四 · 午休时间 · 在电脑前" with
  lunch/at-computer bubbles (法语词 / 理解模块 / 夺回方向盘 / 发一句真话).

What still feels wrong / not done yet:
- It surfaces bubbles *in-app*; true push (notify when the app is closed) needs
  Web Push + a service-worker handler + permission — logged as a follow-up
  (quiet-hours/budget logic already exists via `canRemindNow`).
- Location is still a guess unless the user corrects it; a "set home once" step
  would let it be sensed — logged as a follow-up.

---

## Cycle 36: Sense "home" (location detected, not just guessed)

What changed:
- New pure `lib/geo.ts`: `roundCoarse` (coords rounded ~110m before storing),
  `haversineMeters`, `isAtHome` (radius check), `isMovingSpeed`.
- Saved-home plumbing: storage `tdd.home` + `loadHome/saveHome`; store
  `homeLocation` + `setHomeLocation` (loaded on hydrate, cleared on reset).
- `AmbientBubbles`: the opt-in sense is now "感知我现在在哪" → one `getCurrentPosition`:
  moving (speed) → 路上; near saved home → 在家; away → 在外面; and if no home is
  saved yet, it offers "把这里设成家" (stores the coarse coords). Location still
  one-tap-correctable.
- New copy; `geo.test.ts` (4) + store home test.

Why:
- Follow-up to the user's request: make location *sensed*, not only guessed.
  Privacy kept strict — coords are rounded coarse, compared only on-device, and
  never sent anywhere; the whole thing is opt-in behind a tap (permission prompt
  only then).

What was tested:
- `npm run typecheck` clean; `npm test` → 192/192 (26 files); `npm run build` green.

Next:
- Cycle 37: gentle nudges (notification layer honoring quiet-hours + budget),
  with true Web Push wired behind a VAPID env key (dormant without a backend).

---

## Cycle 36: Sense "home" (location detected, not guessed)
- `lib/geo.ts` (pure): coarse-rounded coords, haversine, isAtHome, isMovingSpeed.
- Saved home in storage/store; the Home opt-in sense resolves 路上 / 在家 / 在外面
  and offers "把这里设成家". Coords rounded ~110m, on-device only, opt-in.
- `geo.test.ts` (4) + store home test.

## Cycle 37: Gentle nudges (notification layer)
- `lib/nudge.ts` (pure): daily count + `shouldNudge` (reuses `canRemindNow`).
- `NudgeManager` (app-wide): nudges only when the app is backgrounded and a fitting,
  non-quiet, in-budget moment passes; SW `notificationclick` + `push` handlers.
- Settings "轻轻提醒" toggle (requests permission, honest copy). `nudge.test.ts` (8).
- Honest limit: true closed-app push needs a backend + VAPID (SW handler ready).

## Cycle 38: Friction-free circular Home
- Stripped Home to a centred composition: a central action ringed by circular
  opportunity bubbles; removed the trace/recent lists, big button, visible chips.
- `AmbientOrbit` replaced `AmbientBubbles`. `ambientOrbit.test.tsx`.

## Cycle 39: Artistic glass redesign — "bubbles of light over a still field"

What changed:
- Reimagined Home as a quiet atmosphere (frontend-design skill). Signature: a
  luminous **glass orb** ("现在" → /now, the day held) breathing inside a slow
  drifting **aurora**, ringed by **iridescent frosted-glass bubbles** (the wishes).
- Real glassmorphism via `color-mix` on the theme tokens: frosted fills +
  `backdrop-filter` blur, a masked **conic iridescent rim**, specular highlight on
  the orb, large soft halos. A CJK **serif** (`--font-serif`) for the few words.
- Finishing a wish doesn't pop it — it **dissolves into light** (`tdd-dissolve`),
  then the trace settles in serif. All theme-aware (stunning in Soft Ritual dark).
- New animations (`tdd-aurora`, `tdd-dissolve`) all respect `prefers-reduced-motion`.

Why:
- User: "too many buttons/fields … minimalist, centred, circular … artistic with
  bubbles and transparency … surprise me as an artist." The glass-orb-in-aurora is
  the one bold signature; everything else stays quiet (one serif wordmark, one
  ambient line, one "+"). Precise pickers live in /now.

What was tested:
- typecheck clean; `npm test` → 200/200 (27 files); `npm run build` green.
- Verified in the browser across warm-paper and soft_ritual (dark) — the dark
  theme glows like candlelit glass.

What still feels wrong / not done yet:
- `backdrop-filter` / `color-mix` / conic-mask need a modern browser (graceful:
  the translucent gradient still reads as glass if a filter is unsupported).
- Could add a one-time page-load "settle" stagger for the bubbles.

---

## glass 1 (A1): Liquid-glass refraction
- New `GlassFilters` SVG `#tdd-liquid` (animated fractalNoise turbulence +
  displacement). `.glass-refract` inner layer warps a caustic highlight inside
  each bubble + the orb → light bends like real glass. Reduced-motion: filter off.
- Rendered on Home; 214 tests green; typecheck + build clean. Branch luminous-glass.

---

## glass 2 (A2): Caustic edge light
- The iridescent rim now slowly hue-rotates (`tdd-rim-hue`) for a living caustic
  shimmer, and a bright specular **glint** sweeps across each primary bubble + the
  orb (`.glass-glint::before`, staggered per-bubble via `--gd`). Reduced-motion off.
- 214 tests green; typecheck + build clean. Branch luminous-glass.

---

## glass 3 (A3): Depth field
- Each bubble carries a `z` (primaries near ~0.9, lesser ones far ~0.3) driving a
  progressive blur (`blur((1-z)*2.6px)`) and pointer/device-tilt **parallax**
  (near bubbles shift more). Crisp in front, soft in back. Reduced-motion: static.
- 214 tests green; typecheck + build clean. Branch luminous-glass.

---

## glass 4 (A4): Gooey coalesce (liquid metaballs)
- New `#tdd-goo` filter (feGaussianBlur + alpha-threshold feColorMatrix). A
  `.goo-layer` of soft accent `.goo-blob`s is synced under the glass bubbles each
  frame; when bubbles drift/collide close, their blobs fuse into liquid bridges and
  part again. Layer sits behind the glass at 0.5 opacity. 214 tests green.

---

## glass 5 (A5): Dreamier ambience
- Calmer motion (home-pull 0.55→0.42, jitter ±5→±3, damping 0.92→0.94) so the
  field drifts slower. Added a `.dream-motes` layer (9 faint rising light dots,
  staggered) and a soft `.dream-vignette` framing the field. Reduced-motion stills
  the motes. 214 tests green; typecheck + build clean.

---

## glass 6 (A6): Gyro polish
- Tilt is low-pass smoothed (0.82/0.18) so motion glides; a devicemotion **shake**
  (accel jump > 22) flings all bubbles apart (debounced 900ms); when the device is
  near-flat the field eases back to a gentle cluster. 214 tests green.

---

## core 1: Runtime skin picker (Settings → 外观风格)
- `settings.aesthetic` (default = NEXT_PUBLIC_AESTHETIC) now drives the Home look at
  runtime. New `HomeSkin` client component reads the setting (falls back to the env
  default before hydration, no flash) and renders GlassField / OceanField / PaperHome;
  `app/page.tsx` is now a thin wrapper. Settings gains a 3-way 外观风格 picker
  (琉璃/海洋/纸页). Switching is instant + persisted; no rebuild. New homeSkin.test.tsx
  (3); 250 tests green; typecheck + build clean.

---

## core 2: Folder tidy — shared/ + skins/
- Moved the shared home pieces (BubbleField, SceneBackground, NavLayer, SceneWindow,
  GlassFilters, glyphs) into `components/home/shared/`, and PaperHome into
  `components/home/skins/` (dropping the re-export shim). Updated all importers +
  tests. Matches docs/architecture-skins.md. No visual change. 250 tests green.

---

## core 3: Desktop perf pass on the glass effects
- The animated SVG turbulence (`.glass-refract`, per bubble + orb every frame) and
  the full-screen goo metaball filter (`.goo-layer`) are the costly bits on large
  viewports. On `@media (pointer: fine)` (desktop/laptop, where lag was reported)
  they're swapped for a cheap CSS blur; touch devices keep the full richness.
  CSS-only; 250 tests green; typecheck + build clean.

---

## glass 7 (A7): Condense-from-light page-load
- Each bubble now condenses out of light into place on load — opacity + the
  independent CSS `scale` property (so it composes with the rAF position transform),
  staggered via animationDelay. Mutually exclusive with the dissolve animation;
  reduced-motion stills it. Shared field, so glass + ocean both get it. 250 tests green.

---

## ocean 3: Rise-from-the-floor load
- Ocean skin only: on first build, bubbles spawn at the bottom edge (the ocean
  floor) and the buoyancy physics floats them up to their relevance-heights — a
  gentle rise into place. One-shot via didRiseRef (no re-rise when the field
  rebuilds after an interaction). Glass unaffected. 250 tests green.
