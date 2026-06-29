# Next steps — skins-on-main backlog

One narrow item per overnight tick (see `docs/tick-playbook.md`). Mark `[x]` when
shipped. Keep core skin-agnostic; keep skins thin.

## Core (every skin inherits)
- [x] Folder tidy: shared pieces → `components/home/shared/` (BubbleField, SceneBackground, NavLayer, SceneWindow, GlassFilters, glyphs); PaperHome → `skins/`. Imports + tests updated; 250 green. _(core 2)_
- [ ] `packages/design` extraction + CI on luminous. (`packages/core` ✓ done — core 31–37.)
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
- [x] Dev ergonomics: added `npm run dev:https` (Next self-signed cert) + a README note, so the mic/motion senses are testable on a phone (secure context). _(core 42)_
- [x] **感受周围 failure is now visible** (user: "cannot click it"): the mic needs a secure context (localhost/https) — over a plain-http LAN IP the browser blocks it silently. `useSensors` now sets `ambientBlocked`; both homes show a gentle note (打不开麦克风 · 在本机或 https 才行) instead of a dead button. _(core 41)_
- [x] Updated the native handoff brief (`docs/ios-sensor-port.md`): points at `@luminous/core` (not the moved `lib/` paths), and spells out the **RN path — consume `@core` directly, zero reimplementation** vs SwiftUI mirroring. _(core 39)_
- [x] Docs accuracy + package surface: CLAUDE.md/README Layout now say the domain lives in `@luminous/core` (not lib/); added a subpath `exports` map so RN can import `@luminous/core/<module>` (inert for web). _(core 38)_
- [x] **@core boundary guard**: corePurity now also fails if any packages/core file imports the app (`@/…` or `../`) — locks the extraction's invariant so @core stays RN/iOS-portable. _(core 37)_
- [x] **Started `packages/core`**: real `packages/core/` dir + `@core/*` alias (tsconfig + vitest + Next all resolve it); moved the zero-dep sensing classifiers (sensors/dwell/battery) there; purity guard now scans it. Green end-to-end. _(core 31)_
- [x] **packages/core — slice 2**: moved `utils` + `geo` (both zero-dep) into `@core` (25 importers rewritten). _(core 32)_
- [x] **packages/core — slice 3**: moved `types` + `aesthetic` (the keystone; 40 importers) into `@core`. _(core 33)_
- [x] **packages/core — slice 4**: moved `semanticTime`/`categoryMeta`/`copy`/`illustration`/`weather`/**`scoring`** (the recommender) into `@core` (52 importers). _(core 34)_
- [x] **packages/core — slice 5**: moved the rest of the pure domain (context/ambient/mockSeeds/seedParser/traceGenerator/seedAiPrompt/reminders/exportTraces). `@core` = 21 modules; `lib/` is now the platform boundary. _(core 35)_
- [x] **packages/core — finished**: `@core` is now `@luminous/core` (real package.json) holding the whole framework-free domain (23 modules incl. bubblePhysics/aiParser); web consumes it via the `@core/*` alias. `lib/` is purely the platform boundary now. _(core 36)_
- [ ] When the RN/iOS app is created: add `@luminous/core` as a workspace dep there (+ `transpilePackages` if needed). No web change required.
- [x] Docs: refreshed `CONTEXT.md` (sensing fusion table + illustration packs + boxless wishes; dropped the dead café NavLayer) and wrote a real `README.md` (was create-next-app boilerplate). _(core 30)_
- [x] **Boxless wishes** (user): dropped the glass card around primary wishes — now a bigger free-floating illustration + title (no box). Glass rings the orb; ocean rises in the upper band. _(glass 13)_
- [x] End-to-end fusion test: a weary context (long sit + low battery) provably lifts the restful wish + lowers focus through recommend, not just in isolated bonuses. _(core 29)_
- [x] Consolidated the sensing hooks into one `useSensedSignals()` (motion/loudness/dwell/weather/battery) — BubbleField, PaperHome, NowFlow all read it, so the next signal is a one-file add. Behavior-neutral. _(core 28)_
- [x] **Now flow is sensor-aware**: /now folded the passive senses (motion/loudness/dwell/weather/battery) into its recommendation context, so the deliberate ask is as keen as the home (was using only the stated answers). _(core 27)_
- [x] **Weather sensing wired** (was a written-but-unused helper): when a coarse home is saved, fetch open-meteo (key-free), classify, derive isOutdoorWeatherGood → lifts "step outside" wishes. On-device opt-in; never forces. _(core 24)_
- [x] Weather shows in the day-line beside place (晴/多云/雨/雪/雾/雷雨). _(core 25)_
- [x] Weather tints the field — a soft veil (rain/snow/fog/storm/cloud) over the scene on glass/ocean; clear adds nothing. _(glass 12)_
- [x] **Distinct wish illustrations** (user: "icons too similar"): wishes sharing a category looked identical; now the illustration varies across a wish's own categories (lib/illustration), and the 3 home cards are forced distinct. _(core 21)_
- [x] Replaced the remaining system emojis with the illustration (Now flow / seed detail / add preview / recent list), varied by category. TraceCard stays warm. _(core 23)_
- [x] **Dwell sensing** (smarter/temporal): tracks active minutes at the desk today (on-device, per-day localStorage); long sit → ranking favors body/rest/outside + the day-line says 坐了一会/坐了挺久. _(core 22)_
- [x] PaperHome sensing parity: dwell + weather now feed paper's ranking + day-line (the tint stays glass/ocean — paper keeps its notebook look). _(paper 1)_
- [x] **Battery signal**: low + unplugged → a soft winding-down proxy; ranking favors small/restful, eases off long/high-energy. On-device, no permission. _(core 26)_
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
- [ ] **iOS/RN: port (or consume) the sensor fusion** — brief: `docs/ios-sensor-port.md`. The brain is now `@luminous/core`; **RN can consume it directly (zero reimplementation)**, SwiftUI mirrors it. (Mac.)
- [x] a11y bug: under prefers-reduced-motion the physics loop never ran, so bubbles stacked unpositioned at the corner — now placed at their homes statically (no animation). _(core 9)_
- [x] Tidy: removed dead `AmbientOrbit` (pre-bubble-field Home leftover) + its test; corrected the BubbleField doc comment to match the settle-then-rest motion. _(core 8)_
- [x] Geo search in **every** web skin: NavLayer (Overpass nearby café/attraction + true-bearing arrow) was only on glass/ocean; added to paper too (a skin-fitting `soft` variant). _(core 7)_
- [x] Motion rework (user feedback): removed pointer-tracking everywhere; a firm spring flows bubbles in and **rests** them (no drift/jitter); gyro tilt is a **slight** lean only, desktop is still. _(core 6)_
- [x] Tone fix: the shared field's motion button reads 感受水流 on the ocean skin (current), 感受重力 on glass — no more "gravity" under a buoyancy metaphor. _(core 5)_
- [ ] iOS: build `ios-glass` in Xcode and confirm the sense/craft reconciliation compiles + reads well (Mac task).
- [ ] **Decide React Native vs SwiftUI** — the `packages/core` prerequisite is ✓ done, so this is now purely the product call. (Recommendation in `docs/CONTEXT.md`: RN + `@luminous/core`.)
- [ ] (optional, needs product-tone OK) a discreet on-Home skin cue so users can flip looks without opening Settings.
- [ ] Keep the keepsake card intentionally warm across all skins (decision recorded — do not re-skin it).
