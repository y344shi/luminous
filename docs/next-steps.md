# Next steps — skins-on-main backlog

One narrow item per overnight tick (see `docs/tick-playbook.md`). Mark `[x]` when
shipped. Keep core skin-agnostic; keep skins thin.

## Core (every skin inherits)
- [x] Folder tidy: shared pieces → `components/home/shared/` (BubbleField, SceneBackground, NavLayer, SceneWindow, GlassFilters, glyphs); PaperHome → `skins/`. Imports + tests updated; 250 green. _(core 2)_
- [ ] Real `packages/core` / `packages/design` extraction + CI on luminous (was C6).
- [x] A Settings "外观风格" picker sets the aesthetic at **runtime** (persisted): `HomeSkin` reads `settings.aesthetic` (falls back to `NEXT_PUBLIC_AESTHETIC` pre-hydration); flip glass/ocean/paper in-app, no rebuild. _(core 1)_
- [ ] Perf pass on the glass effects for large desktop viewports (backdrop-filter +
  SVG goo/turbulence cost).

## glass skin
- [ ] A7 page-load choreography: bubbles condense out of light into place (staggered).

## ocean skin
- [ ] Rise-from-the-floor load: bubbles spawn at the floor and float up (staggered).
- [ ] Caustic water surface + light shafts from the top; faint bubble streams.

## paper skin
- [ ] Hand-drawn entrance for the notes; a pressed-flower mark per category.
