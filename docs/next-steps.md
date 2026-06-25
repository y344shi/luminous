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
- [ ] Enforce quiet-hours + max-reminders once local notifications exist (a `isQuietNow(settings, date)` helper + reminder budget). Currently the settings are stored & editable but nothing reads them yet.

## Platform
- [ ] Extract `packages/core` + `packages/design` ahead of iOS.
- [ ] Prisma schema + server storage adapter (Phase 2), offline-first.
- [ ] Wire the live model call in `/api/seeds/parse` when `ANTHROPIC_API_KEY` is set: call Claude with ONLY the wish text, validate the response against the `SeedDraft` shape, fall back to `parseSeedMock` on any error. No key in this env, so left as a seam.

- [x] Per-theme contrast audit (esp. `--text-muted` on `--surface-soft`) across all 5 themes; tune tokens where WCAG AA fails. _(Cycle 13)_
- [x] Accent-as-small-text contrast: added `--accent-text` (darker) variant for text-sized accent, keeping `--accent` vivid for fills. _(Cycle 14)_

## Self-review lenses to run (Cycle 10)
Product designer · ISFP user · tired user at 3AM · technical maintainer · future iOS dev → write `docs/morning-review.md`.
