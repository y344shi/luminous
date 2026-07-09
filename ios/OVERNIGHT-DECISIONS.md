# Overnight autonomous session — decisions log (2026-07-09 night)

Every judgement call made while you were away, for your morning review. I acted
on best judgement throughout and never blocked; reverse anything freely.
Working branch `ios-aware`, fast-forwarded to `ios-glass`/`macos` each push.
Cadence: ~10-minute phases, each committed + pushed with a green gate
(`swift test` + iOS build); revert anything that can't go green (never leave the
trunk red). Whole-picture tracker: `ios/WORKLIST.md`.

## Decisions

**D1 · Parallel agents thrashed the Mac → switched to sequential.**
I launched three background agents (calendar, planetary, Build-Today CP-A). Two
were killed by a stall watchdog — three concurrent `xcodebuild`s saturated the
machine (the exact "laptop feels stuck" risk). *Decision:* recovered every
agent's work by hand (verified `swift test` + builds, then committed on their
branches), and for the rest of the night I run **strictly sequential — no
concurrent Xcode builds, no more build-heavy parallel agents.**

**D2 · Consolidated all three onto the trunk (clean).**
Merged `ios-calendar` → `ios-buildtoday` → `ios-planet` into `ios-aware`; git
auto-resolved the only overlap (`Package.swift`, both additions kept). Verified
**78 tests + iOS build green**, pushed. Now on the trunk: the wish calendar,
Build-Today CP-A (felt rating), and the PlanetPhysics core.

**D3 · Calendar grouping = weekday (accepted the agent's choice).**
The calendar-stack groups wishes by the weekday each was caught (a gentle
look-back, not a schedule), colored by category. Kept it — fits the no-deadlines
philosophy and gives the contrast utility varied colors to prove.

**D4 · Late-night care shipped as a banner; rework queued.**
The get-home care went out as a banner and is on all your devices. Your feedback
(make it orbiting guiding stars + LLM place-type sensing) is queued as **W3a/W3b**
and sequenced *after* the planetary upgrade so it can reuse the richer star
system. Not lost.

**D5 · New task captured: skin-specific home behaviors (W5).**
Your note that only glass should be "planetary", ocean should be literal liquid
(gyro), and paper should be a plain recommendation-ordered list — added to the
worklist as **W5** (a large, multi-part home refactor). Sequenced after the
planetary work (W2), since W2 defines the "planetary/glass" behavior W5 isolates.

**D6 · Deferred W2b (planet↔Home integration) to a fresh cycle.**
W2b edits the beloved core (OrbitSim + HomeView orbit rendering). Rather than
rush delicate surgery at the tail of a very long turn, I stopped at the clean
consolidation checkpoint (green + pushed) and scheduled the next ~10-min cycle
to do W2b with fresh context — one narrow, careful phase. Disciplined over fast.

## Cycle plan (each ~10 min, one phase, committed + pushed, green-gated)
1. ✅ Consolidate the three agent branches (done, pushed).
2. ⏭ **W2b** — size planets by importance (`PlanetPhysics.diameter`); important
   wishes closer (`PlanetPhysics.homeRadius`); importance = normalized opp score.
3. **W2c** capture fly-in · **W2d** moons via shooting stars.
4. **W3a** late-night orbiting stars · **W3b** LLM situational sensing.
5. **W5** skin split (glass planetary / ocean liquid / paper list) — big; may
   take several cycles.
6. **W4 CP-B+** SceneKit day-object.
Revert any phase that can't go green; log it here; continue.

## Open judgement I'll exercise tonight (will log each here as it happens)
- Integrating PlanetPhysics into the live planetarium (W2b–d) **conservatively**:
  if any sub-feature risks destabilizing the beloved home, I ship the safe
  version and log the tradeoff rather than gamble on the trunk overnight.
- Anything that can't reach a green gate in one phase → reverted, logged, moved on.

**D7 · W2b shipped (importance → size + radius).** Planets now render sized by
importance and orbit closer to the glass when important, via the tested
PlanetPhysics helpers. Conservative: only the home-radius (spring target) and
render diameter changed; the integrator, tilt, rest-pose baseline and ring
spring are untouched. Radius floored at 88 so important planets never dive into
the photon ring. 78 tests + iOS build green. Next: W2c (capture fly-in).

**D8 · W2c shipped (capture fly-in).** An important wish you'd set aside
(sleeping, importance>0.5) now flees in from ~2.2× its home radius at a
sub-escape prograde velocity and is gravitationally captured — the ring-spring
settles it onto its orbit. Only a body's FIRST spawn is affected; existing
planets never re-fly. Off under Reduce Motion. captureSpawn's boundedness is
already unit-tested (ε<0). 78 tests + iOS build green. Next: W2d (moons via
shooting stars).

**D9 · W2d shipped (moons via shooting stars) — completes W2.** OrbitSim now
supports kinematic moons: a body with a parentId is placed each frame on a small
local orbit around its parent's live position (PlanetPhysics.moon* — tested),
excluded from the central integration; sync keeps moons, syncMoons reconciles
them, isPlanet guards. HomeView surfaces up to 2 related sleeping wishes (share a
category with a displayed primary) as fly-by stars; tapping opens a
confirmationDialog: become a moon of X, or a separate star (which wakes it to its
own planet). **Tradeoff logged:** the moon map is transient @State this session —
NOT persisted across launches. A future phase can persist it (a small
[seedId:parentId] store) if the interaction proves loved. 78 tests + iOS green.
All of W2 (the planetary science module) is done. Next: W3a (late-night orbiting
guiding stars).

**D10 · W3a shipped (late-night care → orbiting guiding stars).** Replaced the
rounded banner card (LateNightCareView, deleted) with LateNightCareOrbit: a few
care bubbles that shoot in from the edge and slowly orbit the glass, each
tappable — the station one carries a north-arrow rotated by
LateNightCare.arrowAngle(bearing, heading). Self-contained circular layout
(its own TimelineView, NOT the wish OrbitSim). Reduce Motion → static ring, no
shoot-in. All the openers (Maps station, transit route home, Uber, enable
沿-sensing) moved over; the code-owned safety copy and showLateNightCare gate
kept. 78 tests + iOS build green. Next: W3b (the model chooses the warm line +
which guiding stars from place type + surroundings).

**D11 · W3b shipped (situational sensing) — completes W3.** Sensors gained
reverse geocoding (placeLabel via areasOfInterest/name/subLocality/locality) and
a `surroundings` line. SituationCare.swift: the on-device model reads the coarse
place type + nearby kinds + station/home/weather/hour and returns a warm caption
line + a set of intents (⊂ goHome/transit/cab/water/rest); LateNightCareOrbit
shows the line and builds its guiding stars from the intents, never inventing an
unavailable action. Deterministic fallback used immediately + whenever the model
is away; ForbiddenWords on the line; cached ≤1h; the late-night gate stays
code-owned. In the Simulator this uses the fallback by design. 78 tests + iOS
green. Next: W5 (skin split — big).

**D12 · W5a shipped (Home splits by skin).** HomeView body now branches:
skin == glass renders the full planetarium exactly as before (orbits, black
hole, constellation, moons, birth ceremony, late-night orbiting care); ocean &
paper render wishListField — a calm scroll of the shown wishes in recommendation
order (primaries first), each a tappable row (glyph + title + minimum action +
place badge), with a compact tappable orb at top for 现在别消失. This IS paper's
final home (W5c) and a placeholder for ocean until W5b builds the liquid field.
TRADEOFF LOGGED: the late-night get-home orbit currently lives inside the glass
branch, so on ocean/paper there is no late-night care yet — re-add it (skin-
agnostic, or a list-friendly variant) during W5b/W5c. 78 tests + iOS green.
Next: W5b (ocean liquid buoyancy — big).

**D13 · W5b shipped (ocean = literal liquid).** OceanSim.swift (pure, Foundation-
only, 5 invariant tests): a 2D buoyancy field — each wish is a bubble whose
radius grows with relevance and which floats toward a rest depth that is
shallower the more relevant it is (relevant = bigger = higher); the raw gyro
(rest-pose learned internally, like OrbitSim) sloshes them sideways; a gentle bob
keeps it alive; pairwise separation prevents overlap; everything clamps to the
visible water so small wishes never sink off-screen. OceanField.swift renders the
bubbles over a water gradient; HomeView's ocean branch uses it (paper still the
list). Tap a bubble → the wish sheet. 83 tests + iOS build green. TRADEOFF still
open (from D12): late-night care remains glass-only — to add to ocean/paper in
W5c. Next: W5c.

**D14 · W5c shipped — W5 COMPLETE (skin split done).** Two finishing touches.
(1) Paper reads as paper: wishRow is now a warm note-card — theme.surface fill
(fuller for primaries), a 3pt ruled notebook margin down the left edge, a
hairline border, and a soft shadow. Calm, legible, no physics. (2) Late-night
care re-added to the NON-glass skins (clears the D12/D13 tradeoff): a compact
LateNightCareStrip renders at the top of the ocean/paper home when showLateNight-
Care && skin != glass — the day-line, then a horizontal row of the same care
chips (车站·距离 / 回家的路 / 叫一辆车 / 喝口温水 / 就地歇一会, or 帮我看路 when
sensing is off), built from the SituationSense line + intents (deterministic
fallback). It does not orbit — a tappable strip fits a list/liquid home; the
glass skin keeps the orbiting-stars version. DECISION: factored the three openers
(maps route home / transit / cab) into a shared LateNightActions enum so the
orbit and the strip share one code-owned implementation — refactored
LateNightCareOrbit to call it too (small, safe, build-verified). Late-night gate
(showLateNightCare) + all safety copy stay in code, never in a prompt. 83 tests +
iOS build green. Next: W4 CP-B (SceneKit day-object, per BUILD-TODAY-PLAN.md).

**D15 · W4 CP-B shipped — the SceneKit stage exists.** The day-object (今天的
小机器) now has a real center-stage surface. DECISION: went with SceneKit (the
plan's recommended renderer) via SwiftUI's SceneView — genuine 3D, ships with
iOS/macOS, no dependency. Confirmed it builds green on iOS with a StageColor
typealias (UIColor/NSColor) so the scene is cross-platform. CP-B ships the EMPTY
stage only (per the conservative "smallest green slice" rule): DayObjectStage
builds an SCNScene — a pedestal cylinder + thin brass torus rim under one warm
omni key light + surface-tinted ambient, a translucent emissive "seed" sphere
hovering, the whole group slowly rotating (26s) with the seed breathing; Reduce
Motion drops both animations. All colors read from the passed ThemeTokens →
re-skins with the app. BuildTodayView hosts it with a count-free caption (never
"N parts", never "incomplete"). Reachable from Home via a new cube.transparent
button in bottomOverlay → Route.buildToday; added the case to BOTH
navigationDestination switches (HomeView + GardenView — the exhaustive-switch
build error caught the second one). No parts yet (CP-C). New files are UI-only
(SwiftUI/SceneKit) so they auto-join the app target and correctly stay OUT of the
pure test package and the watch target. 83 tests + iOS build green. Next: W4 CP-C
(parts attach from today's DayObject onto the stage).

**D16 · W4 CP-C shipped — parts attach onto the stage.** DayObjectStage now
takes `parts: [DayPart]` and, when non-empty, renders one node per part instead
of the empty seed. Each node is driven entirely by the pure model: geometry by
PartMaterial (glass/light → sphere, light emissive; brass → metallic torus;
cloth → soft chamfered box; wood/paper → matte box), node scale = DayPart.scale
(0.6…1.3), emission intensity = DayPart.glow, and idle motion by DayPart.motor —
a working part spins (faster the stronger the feeling), a quiet tinyButReal part
(motor 0) only breathes; Reduce Motion stills everything. Parts sit evenly on a
ring atop the pedestal (angle = 2π·i/count). Colors all from theme tokens →
skin-aware. DECISION: kept per-material geometry (not per-kind) for CP-C — it's
the smallest honest slice that already looks distinct, and per-kind shapes are a
CP-F art-pass concern; logged so it's an intentional simplification, not an
oversight. Added a cross-platform `v(Double,Double,Double)→SCNVector3` helper
since computed vector components are Float on iOS / CGFloat on macOS (literal
vectors compiled, computed ones would not). Count-free throughout. No Play scene
(CP-D). 83 tests + iOS build green. Next: W4 CP-D (Play today ~10s scene).

**D17 · W4 CP-D shipped — 播放今天 (the Play scene).** The day-object plays a
gentle ~10s scene. DECISION: to animate on demand, refactored DayObjectStage
from a stateless makeScene()-per-body into a PERSISTENT scene — @State scene +
camera + craft nodes, built once in onAppear and rebuilt only on parts.count /
reduceMotion change. Play is triggered by a `playSignal: Int` prop (bumped by the
button) via .onChange, running SCNActions on the persisted nodes: the sky
background tints (SCNTransaction) to the hour's DayGrade.colors horizon (softened
to the top stop in rain/snow/fog via a `soften` flag), the camera drifts out and
back (5s ease each way), the craft rises and arcs and returns, then after 9.5s
the sky settles back to tokens.background. Gentle throughout — no race. Passing
`pointOfView: camera` to SceneView so the camera dolly reads. BuildTodayView adds
a 播放今天 capsule button shown only when the object has parts AND motion is on;
tapping it also sets a soft scene line by DayGrade.phase (garden path / through
clouds / over water / under the night sky), with a rain addendum. Reduce Motion →
button hidden, scene stays a still hero pose. All colors from theme tokens +
DayGrade → skin-aware; count-free. NOTE: SceneKit Play verifies best on device;
in the Simulator it builds + renders but on-device is the real test (logged for
morning). 83 tests + iOS build green. Next: W4 CP-E (save the assembled object +
a rendered snapshot into the Daily Trace keepsake).

**D18 · W4 CP-E shipped — 收进今天的痕迹 (the keepsake).** The assembled machine
can be kept into 痕迹 with a rendered snapshot. DECISION on storage: reused the
existing persistence seam rather than a new schema — added `keptAt: String?` and
`snapshot: Data?` to the DayObject STRUCT, which rides the DayObjectRecord.payload
JSON (hybrid payload design); no @Model migration, and old payloads decode
loss-free because both are Optional. store.keepToday(snapshot:) sets the marker +
optional PNG and leaves exactly ONE soft trace line (今天的小机器，收好了) on the
first keep (re-keep updates the image only); no-op on an empty machine.
DECISION on rendering: DayObjectSnapshot renders a STILL, animation-free copy of
the scene offscreen via SCNRenderer → PNG, nil-safe when Metal is unavailable
(the keepsake still works from the marker + trace line). It deliberately
DUPLICATES the small node-mapping (geometry/material/placement) instead of
coupling to the animated DayObjectStage — keeps the live stage untouched; the
tradeoff is that CP-F's per-kind shapes must update both places (logged). Snapshot
PNG is stored base64 in the day's JSON — heavy-ish but one per day, acceptable for
a keepsake; could move to a dedicated Data column later if it bloats. BuildTodayView
adds a 收进今天的痕迹 button beside 播放今天 + a soft confirmation. Count-free.
NOTE (device): the Play scene + the snapshot render are best verified on device;
they build and render in the Simulator. 83 tests + iOS build green. Next: W4 CP-F
(final art/skins/a11y polish) — the LAST worklist item.
