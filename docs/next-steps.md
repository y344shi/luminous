# Next steps — skins-on-main backlog

One narrow item per overnight tick (see `docs/tick-playbook.md`). Mark `[x]` when
shipped. Keep core skin-agnostic; keep skins thin.

## Core (every skin inherits)
- [x] Folder tidy: shared pieces → `components/home/shared/` (BubbleField, SceneBackground, NavLayer, SceneWindow, GlassFilters, glyphs); PaperHome → `skins/`. Imports + tests updated; 250 green. _(core 2)_
- [ ] Real `packages/core` / `packages/design` extraction + CI on luminous (was C6).
- [x] A Settings "外观风格" picker sets the aesthetic at **runtime** (persisted): `HomeSkin` reads `settings.aesthetic` (falls back to `NEXT_PUBLIC_AESTHETIC` pre-hydration); flip glass/ocean/paper in-app, no rebuild. _(core 1)_
- [x] Desktop perf: on `@media (pointer: fine)` (desktop/laptop) the per-bubble animated SVG turbulence + the full-screen goo filter are swapped for a cheap CSS blur; touch keeps the full richness. _(core 3)_

## glass skin
- [x] A7 page-load choreography: each bubble condenses out of light (opacity + independent `scale`, staggered `animationDelay`) into place; mutually exclusive with dissolve; reduced-motion safe. _(glass 7)_

## ocean skin
- [x] Rise-from-the-floor load (ocean): on first load bubbles spawn at the bottom edge and float up to their relevance-heights via buoyancy; once only (no re-rise on rebuild). _(ocean 3)_
- [x] Ocean ambience: a caustic water **surface** band, slow **light shafts** from the top, and faint rising **bubble streams** — a decorative layer in the OceanField skin only; reduced-motion safe. _(ocean 4)_

## paper skin
- [x] Paper polish: notes are laid hand-by-hand (staggered `tdd-rise`), and each carries a faint **pressed-flower** mark — a botanical line-art stamp that varies by category. _(paper 3)_

## Fresh (self-review — needs a green tick each)
- [x] Sensing is now **clickable + automatic**: motion samples passively; ambient (mic) auto-resumes on load once opted-in (`settings.senseAround`, permission persists → no re-prompt); 感受周围 is the one-time trigger. _(core 11)_
- [x] Make the sensing visible: the ambient line now surfaces the fused senses — 走着/在路上 (motion) and 周围很安静/周围有点热闹 (loudness) — so the app's keenness shows. _(core 10)_
- [x] **Sensor-fusion ranking** (the real core idea): the recommender now fuses motion (accelerometer→activity), ambient loudness (opt-in mic→quiet/lively), location, time + weather; `scoring.sensorBonus` nudges which tiny action fits *now*. Café-finder removed. All on-device. `感受周围` opt-in. _(sense 1–3)_
- [ ] **iOS: port the sensor fusion** — brief written for the Mac agent in `docs/ios-sensor-port.md` (CoreMotion · AVAudioSession · HealthKit HR→arousal · CoreLocation, mirroring `lib/sensors.ts` + `sensorBonus`). (Mac/Swift.)
- [x] a11y bug: under prefers-reduced-motion the physics loop never ran, so bubbles stacked unpositioned at the corner — now placed at their homes statically (no animation). _(core 9)_
- [x] Tidy: removed dead `AmbientOrbit` (pre-bubble-field Home leftover) + its test; corrected the BubbleField doc comment to match the settle-then-rest motion. _(core 8)_
- [x] Geo search in **every** web skin: NavLayer (Overpass nearby café/attraction + true-bearing arrow) was only on glass/ocean; added to paper too (a skin-fitting `soft` variant). _(core 7)_
- [x] Motion rework (user feedback): removed pointer-tracking everywhere; a firm spring flows bubbles in and **rests** them (no drift/jitter); gyro tilt is a **slight** lean only, desktop is still. _(core 6)_
- [x] Tone fix: the shared field's motion button reads 感受水流 on the ocean skin (current), 感受重力 on glass — no more "gravity" under a buoyancy metaphor. _(core 5)_
- [ ] iOS: build `ios-glass` in Xcode and confirm the sense/craft reconciliation compiles + reads well (Mac task).
- [ ] Decide React Native vs SwiftUI (see chat) — prerequisite is the `packages/core` extraction above.
- [ ] Add-flow + Garden visual cohesion: make sure every route feels at home under each skin's palette.
- [ ] (optional, needs product-tone OK) a discreet on-Home skin cue so users can flip looks without opening Settings.
- [ ] Keep the keepsake card intentionally warm across all skins (decision recorded — do not re-skin it).
