# Worklist — open threads, in sequence (2026-07-09)

The running tracker for everything in flight. Sequenced so entangled work
(anything touching the planetarium / `OrbitSim` / `HomeView`) happens in a
sane order. Branch: all native work on `ios-aware`, fast-forwarded to
`ios-glass`/`macos` each commit. The calendar view is on its own branch.

Legend: ✅ done · 🔄 in progress · ⏳ queued · ⏸ paused

---

## Parallel (independent, running now)
- 🔄 **W1 · Wish calendar-stack view** — a side agent is building it on branch
  `ios-calendar` (worktree `wt-calendar`): seven day-stacks, cards flying in in
  parallel, finger-in-a-book hover-split, heaviness by count, and a
  `DemoRGBColor` / `contrastingTextColor` readability utility. Backed by the
  existing SwiftData store. **Next action: review + merge when it reports.**

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
- ⏳ **W2b — Home integration:** render planet **size by mass**; important wishes
  sit **closer to the glass**; wire importance from `Scoring`. Keep the tilt +
  ring-spring behaviour intact.
- ⏳ **W2c — Capture fly-in:** important sleeping/off-schedule wishes flee in and
  are captured (spawn at edge with sub-escape velocity → settle into orbit).
- ⏳ **W2d — Moons via shooting stars:** related wishes fling by as shooting
  stars; tap one → choose **become a moon** of a related orbiting wish, **or**
  keep as a separate shooting star / its own planet. (A `PursuitMerge`-style
  relatedness read can pick "related".)

### W3 · Late-night get-home care — rework
- ⏸ Shipped as a **banner** (aware 29). Rework to fit the planetarium & be
  sensing-driven:
- ⏳ **W3a — Orbiting guiding stars:** replace the banner with bubbles that
  shoot in and **orbit** the glass (station carries the direction arrow; tap →
  Maps / cab / route home). Reuses W2's richer star/orbit system.
- ⏳ **W3b — LLM situational sensing:** the on-device model reads the **type of
  place + surroundings** (reverse-geocoded label + nearby kinds + distance from
  home + time) and chooses the warm line and which guiding stars appear.
  Deterministic fallback; late-night gate stays code-owned; `ForbiddenWords`.

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
