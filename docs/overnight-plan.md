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
- [x] A1. Real refraction: SVG `feTurbulence`+`feDisplacementMap` (`GlassFilters` `#tdd-liquid`) warps a drifting caustic highlight inside each bubble + the orb (`.glass-refract`), reduced-motion safe. _(glass 1)_
- [x] A2. Caustic edge light: the iridescent rim slowly hue-shifts (`tdd-rim-hue`) + a bright specular **glint** sweeps across each bubble + the orb (`.glass-glint`, staggered via `--gd`); reduced-motion safe. _(glass 2)_
- [x] A3. Depth field: each bubble gets a `z` (primaries near/crisp, lesser ones far) → progressive blur + size, and pointer/tilt **parallax** scaled by z (near moves more). Reduced-motion → static. _(glass 3)_
- [x] A4. Gooey coalesce: an SVG `#tdd-goo` (blur + alpha threshold) on a metaball layer of soft accent blobs synced under each bubble — they fuse into liquid bridges when bubbles drift close, separate as they part. _(glass 4)_
- [x] A5. Dreamier ambience: calmer drift (gentler home-pull + less jitter), faint drifting light **motes**, and a soft **vignette** framing the field. Reduced-motion stills the motes. _(glass 5)_
- [x] A6. Gyro polish: low-pass **smoothed tilt**, **shake-to-scatter** (devicemotion jolt flings bubbles), settle easing when near-flat. _(glass 6)_
- [ ] A7. Page-load choreography: bubbles condense out of light into place (staggered).

## B · Living World  (branch `luminous-sense`)
- [ ] B1. Scene wallpaper upgrade: curated high-res images per scene (Unsplash/Pexels seam, env-keyed), gradient fallback.
- [ ] B2. 3D/parallax scene layer (CSS 3D transform or a tiny Spline/three embed) for top scenes.
- [ ] B3. Floating nav map: Overpass nearby cafés → true bearing + distance arrow to the nearest Starbucks, as glass markers.
- [ ] B4. Weather signal (open-meteo, key-free): scene + tint react to rain/sun/cloud.
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

## D · Ocean  (branch `luminous-ocean` → luminous `ocean`)
A buoyancy reskin of the glass field: the screen is water, the **bottom edge is the
ocean floor**, and wishes **float by relevance** — the most relevant rise to the
surface (top), lesser ones hover lower. Gentle bob; gyro = a horizontal current.
- [x] D1. Buoyancy model: relevance→float-height, vertical bob, gyro as current (not gravity); floor = bottom edge. _(ocean 1)_
- [ ] D2. Rise-from-the-floor load: bubbles spawn at the floor and float up into place (staggered).
- [ ] D3. Caustic water surface + light shafts from the top; faint bubble streams.
