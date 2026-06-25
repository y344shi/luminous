# Next Steps — Morning Review List

Prioritized backlog for overnight agentic cycles and the morning review.

## High value, low risk (do first)
- [x] PWA manifest + icons + service worker (add-to-home-screen). _(Cycle 2)_
- [x] Now screen: one-tap context chips for "我在外面" / "天气不错" / "在电脑前" feeding `locationHint` + `isOutdoorWeatherGood`. _(Cycle 3)_
- [x] Auto-offer `soft_ritual` theme at late night (non-forcing). _(Cycle 4)_
- [x] Richer empty states + gentle Now→trace transition animation. _(Cycle 5)_
- [x] Self-written trace option (edit the generated sentence). _(Cycle 6)_

## Quality
- [x] Integration test driving the full Now flow via the store (jsdom + Testing Library). _(Cycle 7)_
- [x] Copy-lint test: assert `forbiddenWords` never appear in rendered screens. _(Cycle 8)_
- [x] Test that `data-theme` is applied + persisted. _(Cycle 9)_
- [x] Accessibility pass: focus states, aria labels, contrast in every theme. _(Cycle 12 — focus + ARIA done; per-theme contrast audit still worth a deeper look)_

## Product depth
- [x] Seed detail page `/seeds/[id]` (edit, sleep, archive). _(Cycle 10)_
- [x] Quiet-hours + max-reminders UI in Settings (model exists). _(Cycle 11 — UI done; enforcement still pending, see below)_
- [x] Real-AI parser behind `aiMode: "real"` (server route, coarse input only). _(Cycle 15 — seam + route + fallback shipped; live model call is a documented, key-gated TODO)_
- [x] `isQuietNow(settings, date)` helper + reminder budget (`remindersRemaining`/`canRemindNow`) with a live Settings indicator. _(Cycle 16)_ Full enforcement still waits on local notifications existing.

## Platform
- [ ] Extract `packages/core` + `packages/design` ahead of iOS.
  - [x] Precondition: core-purity guard test — `lib/` (minus `store.ts`) imports no React/Next/Zustand. _(Cycle 27)_ The lift itself (workspaces config) is the risky remaining part; deferred to a deliberate, non-autonomous session.
- [x] Prisma schema + storage adapter seam (Phase 2). _(Cycle 17 — schema + DB-agnostic validated (de)serialization shipped; live DB connection still deferred)_
- [ ] Live DB wiring (Phase 2): install prisma, set DATABASE_URL, generate client, and add a server `storage` adapter using the existing `deserialize*` boundary; migrate localStorage → server on first login, offline-first.
- [ ] Wire the live model call in `/api/seeds/parse` when `ANTHROPIC_API_KEY` is set: call Claude with ONLY the wish text, validate the response against the `SeedDraft` shape, fall back to `parseSeedMock` on any error. No key in this env, so left as a seam.

- [x] Per-theme contrast audit (esp. `--text-muted` on `--surface-soft`) across all 5 themes; tune tokens where WCAG AA fails. _(Cycle 13)_
- [x] Accent-as-small-text contrast: added `--accent-text` (darker) variant for text-sized accent, keeping `--accent` vivid for fills. _(Cycle 14)_

## Polish (from the Cycle-18 morning review)
- [x] **P1** Replace the `window.confirm` data-reset with an in-app soft confirm sheet (aesthetic consistency). _(Cycle 19)_
- [x] **P1** Token-sync guard test: parse `globals.css` `[data-theme]` blocks and assert they match `themes.ts` (prevent silent drift between the two token sources). _(Cycle 20)_
- [x] **P2** Human trace dates in the journal (今天 / 昨天 / M月D日) instead of raw `YYYY-MM-DD`. _(Cycle 21)_
- [x] **P2** Surface the late-night theme offer on `/now` too (not just Home), where the rescue copy lives. _(Cycle 22)_
- [x] **P2** Associate a real `<label>` with the Add-seed textarea (a11y; currently placeholder-only). _(Cycle 23 — also linked the seed-detail title/min fields)_
- [x] **P2** Explain or make dismissible the first-run mock garden (so it doesn't read as someone else's data). _(Cycle 24)_
- [x] **P2** Add CI (`.github/workflows`) running typecheck + test + build. _(Cycle 26 — path-scoped workflow at the monorepo root; runs only on `dreams/seize_the_day/**` changes. Can't be exercised in this env; YAML validated.)_
- [x] **P2** Show top opportunity with 1–2 muted "或者……" peeks instead of one-at-a-time only. _(Cycle 25)_

## Polish (from the Cycle-28 morning review, round 2)
- [x] **P2** Export/keep traces — a pure `formatTracesForExport()` + a copy-to-clipboard action ("把你的痕迹存下来"). _(Cycle 29)_
- [x] **P2** Remember last mood/energy in the Now flow (persist + pre-select) so a returning user isn't re-quizzed each time. _(Cycle 30)_
- [x] **P2** First-open intro card (dismissible) introducing Seed / Trace / "别消失", reusing the samples-note dismissal pattern. _(Cycle 31)_
- [x] **P3** Per-trace delete / tidy affordance + an eventual journal size cap (traces are append-only and unbounded). _(Cycle 32)_
- [x] **P3** Optionally record a gentle recovery trace for "今天先这样" (onLater currently saves nothing). _(Cycle 33 — offered, not automatic)_

## Self-review lenses to run (Cycle 10)
- [x] Product designer · ISFP user · tired user at 3AM · technical maintainer · future iOS dev → `docs/morning-review.md`. _(Cycle 18)_
