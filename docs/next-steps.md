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
- [x] **Distinct wish illustrations** (user: "icons too similar"): wishes sharing a category looked identical; now the illustration varies across a wish's own categories (lib/illustration), and the 3 home cards are forced distinct. _(core 21)_
- [ ] Replace remaining system emojis with the illustration (OpportunityCard / SeedDetail / AddSeedFlow / RecentSeeds) — keep TraceCard warm.
- [x] **Dwell sensing** (smarter/temporal): tracks active minutes at the desk today (on-device, per-day localStorage); long sit → ranking favors body/rest/outside + the day-line says 坐了一会/坐了挺久. _(core 22)_
- [ ] Dwell follow-ups: wire useDwell into PaperHome too; add session-length + app-open cadence; iOS gets system-wide Screen Time (note in ios-sensor-port.md).
- [x] Lighter wish cards: dropped the cramped action line — cards show illustration + title only (user). _(glass 11)_
- [x] Garden wishes use the chosen illustration pack (dropped the system emoji) — consistent with the home cards. _(core 20)_
- [x] Test coverage for the illustration pack system: all 8 packs registered, every pack category-aware (7 scenes), IllustrationArt renders + falls back. _(core 19)_
- [x] Fix: illustration-style swatches used dark line-art on `--surface-soft`, invisible in the dark soft_ritual theme — gave the previews a fixed light card so they read in every theme. _(core 13)_
- [x] **插画风格 picker in Settings**: 8 hand-painted swatches, one per illustration library (Open Doodles / Storyset / Pixeltrue / Blush / Humaaans / Open Peeps / unDraw / DrawKit), persisted to `settings.illustrationStyle`. Wiring the chosen style to the wishes is next. _(core 12)_
- [x] Researched + recorded **lifestyle-illustration libraries** in `docs/scene-library.md` (Open Doodles / Storyset / Pixeltrue / Blush…) for the "art figure" direction.
- [x] **All libraries, switch on demand** (user direction): pluggable `illustrationPacks` (one interface for all 8 looks) wired to `settings.illustrationStyle`; the picked style renders on the wish sheet + a live preview in Settings. _(core 14)_ Real library assets can drop into the same interface later.
- [x] **Per-category pack art** (API + first pack): packs can now provide `scene(category)`; Open Doodles has all 7 category scenes (book/bowl/leaf/path/pen/two-forms/bloom). Wish sheet + Settings preview pass the category. _(core 15)_
- [x] Storyset is now category-aware (flat 7 scenes). _(core 16)_
- [x] Pixeltrue is now category-aware (soft pastel 7 scenes). _(core 17)_
- [x] **All 8 packs category-aware** — Blush/Humaaans/Open Peeps/unDraw/DrawKit authored in parallel by 5 agents + assembled. Every wish category now has art in every style. _(core 18)_
- [x] **Home wishes are floating cards** (user direction): each primary wish now renders as a small card — per-category illustration + title — on the SAME bubble physics body (glass: ring round the orb; ocean: floating staircase). Ambient wishes stay small bubbles. _(glass 9)_
- [x] Ocean card spacing: near-centered column → collision scatters the 3 cards cleanly, no graze. _(ocean 1)_
- [x] **Action line on the wish cards** — each floating card now shows illustration + title + the one-line action; re-tuned glass ring + ocean spacing for the taller card. _(glass 10)_
- [x] **Artistic glass redesign** (user: "weird, not artistic"): removed the green goo-metaball smudges; the orb is now a clean glass sphere (elegant line glyph + label) cradled in a soft **warm bloom**; fewer, on-screen bubbles. Calm + luminous. _(glass 8)_
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
