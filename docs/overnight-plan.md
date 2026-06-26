# Overnight Plan — 3 directions, 20 experiments

Autonomous overnight build for **luminous** (https://github.com/y344shi/luminous).
Three parallel creative *directions*, each its own git branch, explored on a
5-minute heartbeat. Every change is committed (committed history is a rule — see
`CLAUDE.md`), the timeline is regenerated, and each branch is pushed to its
luminous branch. In the morning, compare the three and choose.

| Direction | foundation branch | luminous branch | bet |
| --- | --- | --- | --- |
| A · Liquid Glass | `luminous-glass` | `glass` | Apple-grade glass, physics, dreamy depth |
| B · Living World | `luminous-sense` | `sense` | the app reflects + navigates your real world |
| C · Calm Ritual | `luminous-craft` | `craft` | a grounded, tactile counter-aesthetic + craft |

Each tick: pick the next unchecked item **for the current direction**, implement
it (use Agent subagents for independent sub-parts; use the frontend-design skill
for visual work), keep the build green, commit, regenerate `docs/TIMELINE.md`,
push the branch. Small > grand. Revert rather than leave red.

## A · Liquid Glass  (branch `luminous-glass`)
- [ ] A1. Real refraction: an SVG `feTurbulence`+`feDisplacementMap` glass filter behind the bubbles so they bend the wallpaper.
- [ ] A2. Caustic edge light: chromatic specular rim on orb + bubbles; a moving glint highlight.
- [ ] A3. Depth field — parallax + progressive blur on far bubbles, crisp in front; size↔z.
- [ ] A4. Gooey coalesce: SVG goo filter so slow-colliding bubbles merge/separate like liquid.
- [ ] A5. Dreamier ambience: slower drift, soft bloom, faint drifting light motes, gentle vignette.
- [ ] A6. Gyro polish: smoothed tilt→gravity, "shake to scatter", settle-to-cluster easing.
- [ ] A7. Page-load choreography: bubbles condense out of light into place (staggered).

## B · Living World  (branch `luminous-sense`)
- [x] B1. Scene wallpaper: richer layered mesh gradients per scene + a curated-image seam (`NEXT_PUBLIC_SCENE_IMAGES` JSON, no hardcoded key); photo layers over the gradient under a theme scrim when configured. _(sense 1)_
- [x] B2. 3D/parallax scene layer: far gradient + near light layer drift by different amounts with pointer / device-tilt (rAF, reduced-motion safe) — depth without a 3D engine. _(sense 2)_
- [x] B3. Floating nav: opt-in geolocation → OpenStreetMap **Overpass** (key-free) nearby cafés → a glass chip with a real **true-bearing arrow** (rotates with the device compass) + name + distance to the nearest Starbucks. `lib/places.ts` pure + tested. _(sense 3)_
- [x] B4. Weather tint: when a home location is saved (already consented), `open-meteo` (key-free) → a soft scene veil for rain/cloud/snow/fog/storm (clear = warm glow). `lib/weather.ts` pure + tested; never changes recommendations. _(sense 4)_
- [ ] B5. Time-of-day color grading across the whole field (dawn → noon → dusk → night).
- [ ] B6. Orb as a living window: the scene icon becomes a tiny illustrated/animated world.
- [ ] B7. Poetic context read: one warm AI line for the moment ("周四的傍晚，电脑前的光").

## C · Calm Ritual  (branch `luminous-craft`)
- [ ] C1. Committed-history discipline + Notion-loadable `docs/TIMELINE.md`, regenerated every cycle.
- [ ] C2. A second aesthetic: a "warm paper / field-notebook" Home — tactile, hand-drawn, slow — to compare against glass.
- [ ] C3. Gentle haptics + optional soft chime on complete (`navigator.vibrate`).
- [ ] C4. Shareable keepsake: render today's trace to a beautiful image card (canvas → PNG).
- [ ] C5. Performance + a11y on the field: pause rAF when hidden, reduced-motion static layout, focus order, caps.
- [ ] C6. Extract `packages/core` + `packages/design`; stand up CI on luminous.
- [ ] C7. PWA push groundwork (VAPID seam) so nudges can reach a closed app.

## Scene library + graphics sources
See `docs/scene-library.md` for the ~100 scenario list and the recommended
free, transparent, high-quality graphics/image/3D libraries to draw from.
