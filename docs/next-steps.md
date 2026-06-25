# Next Steps — Morning Review List

Prioritized backlog for overnight agentic cycles and the morning review.

## High value, low risk (do first)
- [x] PWA manifest + icons + service worker (add-to-home-screen). _(Cycle 2)_
- [x] Now screen: one-tap context chips for "我在外面" / "天气不错" / "在电脑前" feeding `locationHint` + `isOutdoorWeatherGood`. _(Cycle 3)_
- [x] Auto-offer `soft_ritual` theme at late night (non-forcing). _(Cycle 4)_
- [ ] Richer empty states + gentle Now→trace transition animation.
- [ ] Self-written trace option (edit the generated sentence).

## Quality
- [ ] Integration test driving the full Now flow via the store (jsdom + Testing Library).
- [ ] Copy-lint test: assert `forbiddenWords` never appear in rendered screens.
- [ ] Test that `data-theme` is applied + persisted.
- [ ] Accessibility pass: focus states, aria labels, contrast in every theme.

## Product depth
- [ ] Seed detail page `/seeds/[id]` (edit, sleep, archive).
- [ ] Quiet-hours + max-reminders UI in Settings (model exists).
- [ ] Real-AI parser behind `aiMode: "real"` (server route, coarse input only).

## Platform
- [ ] Extract `packages/core` + `packages/design` ahead of iOS.
- [ ] Prisma schema + server storage adapter (Phase 2), offline-first.

## Self-review lenses to run (Cycle 10)
Product designer · ISFP user · tired user at 3AM · technical maintainer · future iOS dev → write `docs/morning-review.md`.
