# Worklist — open threads, in sequence (2026-07-09)

The running tracker for everything in flight. Sequenced so entangled work
(anything touching the planetarium / `OrbitSim` / `HomeView`) happens in a
sane order. Branch: all native work on `ios-aware`, fast-forwarded to
`ios-glass`/`macos` each commit. The calendar view is on its own branch.

Legend: ✅ done · 🔄 in progress · ⏳ queued · ⏸ paused

---

## Done tonight (consolidated on the trunk)
- ✅ **W1 · Wish calendar-stack view** (设置 → 愿望日历) — merged.
- ✅ **W2a · PlanetPhysics core** (pure, 14 tests) — merged.
- ✅ **W4 CP-A · Build Today felt rating** — merged.
  All three built by agents, recovered after a build-thrash watchdog kill,
  verified (78 tests + iOS green), and merged onto `ios-aware`. See
  `ios/OVERNIGHT-DECISIONS.md`.

## Sequence (do in this order)

### W2 · Planetary science computing module (the big physics upgrade)
Extends `OrbitSim` into a real planetary-mechanics module. Sub-steps:
- ⏳ **W2a — PlanetSim core (pure, tested):** per-body **mass from importance**
  (a wish's recommendation score); **radius from importance** (important →
  bigger *and* closer to the centre glass); **same-type attraction** (a weak
  clamped N-body term pulling same-category planets together); **capture**
  (energy-based spawn so an important off-schedule wish *flees in* from the edge
  and is gravitationally captured into orbit); **moons** (a wish can be a
  satellite of another — hierarchical local orbit). Unit tests for mass/radius
  mapping, capture energy < 0, attraction clamp, moon placement.
- ✅ **W2b — Home integration:** planets **sized by importance**
  (`PlanetPhysics.diameter`); important wishes sit **closer to the glass**
  (`OrbitSim.homeRadius` pulls the ring radius inward by importance, floored at
  88 so nothing crosses the photon ring); importance = normalized opp score.
  Tilt + rest-pose baseline + ring-spring preserved. (aware 31)
- ✅ **W2c — Capture fly-in:** an important off-schedule (sleeping, importance>0.5)
  wish spawns far out via PlanetPhysics.captureSpawn (sub-escape → bound) and
  arcs in; the ring-spring settles it. First-spawn only; off under Reduce
  Motion. (aware 32)
- ✅ **W2d — Moons via shooting stars:** OrbitSim gained kinematic moon bodies
  (a body with a parentId orbits its parent's live position, excluded from the
  central integration). Related sleeping wishes (sharing a category with a
  displayed primary) fling by as stars; tapping → 成为「X」的卫星 or 做一颗独立的星.
  Moon map is transient this session (not persisted — logged). (aware 33)

### W3 · Late-night get-home care — rework
- ⏸ Shipped as a **banner** (aware 29). Rework to fit the planetarium & be
  sensing-driven:
- ✅ **W3a — Orbiting guiding stars:** the banner is gone; care actions (station
  with a pointing arrow, 回家的路, 叫一辆车, 喝口温水, or enable-sensing) shoot in and
  gently orbit the glass as tappable stars (LateNightCareOrbit). Reduce Motion →
  static ring. Reuses the pure LateNightCare helpers. (aware 34)
- ✅ **W3b — LLM situational sensing:** Sensors reverse-geocodes a coarse
  placeLabel + surroundings; SituationCare (on-device model) reads place type +
  nearby kinds + station/home/weather/hour → a warm caption line + which guiding
  stars (intents ⊂ goHome/transit/cab/water/rest). Deterministic fallback,
  ForbiddenWords, cached ≤1h; the model only phrases + selects safe actions. (aware 35)

### W5 · Skin-specific home behaviors (big — only glass stays "planetary")
Today every skin shows the orbiting planetarium. Split the Home layout by skin:
- ✅ **W5a — glass = planetary mode:** Home now branches by skin — glass keeps
  the full planetarium (orbits, black hole, constellation, moons, birth,
  late-night orbit), unchanged; ocean & paper get a calm recommendation-ordered
  list (wishListField). Only glass has orbital behavior. (aware 36)
- ⏳ **W5b — ocean = a literal liquid ocean:** water that responds to the **gyro**
  (device tilt) with liquid physics; wishes **float with volume ∝ relevance**
  (more relevant = larger = floats higher/more buoyant); smaller wishes still
  reachable. A real fluid/buoyancy feel, not the orbit sim.
- ⏳ **W5c — paper = a plain list:** wishes as a simple list ordered by the
  recommendation score (no physics) — calm and legible.

### W4 · Build Today — 今天的小机器 (CP-A … CP-F)
- ✅ **CP-A groundwork:** `DayToy` model committed (aware 28).
- ⏳ **CP-A — felt rating + wiring:** *刚才那件事，感觉怎么样?* (很小但真的 /
  挺好的 / 今天因此不一样了) in the completion flow → `store.addPart`; SwiftData
  `DayObjectRecord`.
- ⏳ **CP-B** empty craft on stage (SceneKit) · **CP-C** parts attach ·
  **CP-D** Play today · **CP-E** keepsake · **CP-F** art/skins/a11y.
  (Full plan: `ios/BUILD-TODAY-PLAN.md`.)

## Housekeeping / done recently
- ✅ **Traces write-first** (aware 27) — 痕迹 records your words first; auto-
  installing to both iPhones when they're back on Wi-Fi.
- ✅ Tags (alternatives to fixed facets), save-can't-hang fix, merge-asks-first,
  手帐 delete target, 拍照翻译 speed + editable source + 朗读.
- ✅ Devices: **iPad** + **Mac** on the latest build; **iPhones** pending
  (auto-installer armed).

## Deferred (needs the paid Apple Developer Program — $99/yr)
- iCloud sync (schema ready, compile-gated `CLOUDKIT_ENABLED`), HealthKit
  arousal, TestFlight. Plus: per-word spaced repetition, watch App Group sync,
  web back-port of the pure modules.

---
*Update the marks as we go; this file is the source of truth for "what's next".*
