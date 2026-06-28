# Next steps — skins-on-main backlog

One narrow item per overnight tick (see `docs/tick-playbook.md`). Mark `[x]` when
shipped. Keep core skin-agnostic; keep skins thin.

## Core (every skin inherits)
- [ ] Folder tidy: move shared home pieces into `components/home/shared/` and
  update imports (cosmetic; current code already shares them).
- [ ] Real `packages/core` / `packages/design` extraction + CI on luminous (was C6).
- [ ] A Settings "外观/skin" picker that sets the aesthetic at runtime (localStorage),
  so users can switch glass/ocean/paper without a rebuild.
- [ ] Perf pass on the glass effects for large desktop viewports (backdrop-filter +
  SVG goo/turbulence cost).

## glass skin
- [ ] A7 page-load choreography: bubbles condense out of light into place (staggered).

## ocean skin
- [ ] Rise-from-the-floor load: bubbles spawn at the floor and float up (staggered).
- [ ] Caustic water surface + light shafts from the top; faint bubble streams.

## paper skin
- [ ] Hand-drawn entrance for the notes; a pressed-flower mark per category.
