# Execution plan — 「今天的小机器」 / Build Today

*A center-stage, toy-maker day-object for Luminous, in the spirit of
[mrdoob/toys](https://github.com/mrdoob/toys) — but soft, private, poetic, and
never a productivity toy. Expanded to fit this app's settings, aesthetics, and
the way we ship (build → install to the phone → screenshot at every checkpoint).*

> **The feeling, in one line:** *今天成了一件小小的机器，它动了一下。*
> Today became a little machine, and it moved. Not "you completed 3 things."

Companion to [`VISION-AUDIT.md`](VISION-AUDIT.md) and [`TOUR.md`](TOUR.md).
This is a **review-first** plan: every phase ends at a fixed checkpoint that is
built, installed to your iPhone, and screenshotted for you to look at before the
next phase begins.

---

## 0 · How this fits what Luminous already is

| the toy concept | how it lands in Luminous |
| --- | --- |
| a small day-object you assemble | a **daily** companion to the long-term **记忆星座** — the constellation keeps every trace forever as a star; the day-object holds *just today* and is reborn each morning |
| each fulfilled wish adds a part | each of **today's** completions (`complete()` in `NowView`/`HomeView`) appends one part, by the wish's `SeedCategory` |
| rate how it felt → part size/glow/motor | a new **felt rating** after completion — *very small but real / felt good / today's different now* — orthogonal to Complete/Partial/Skip (which stays the safety-critical loop) |
| "Play today" physics scene | an end-of-day ritual: the craft moves through a ~10 s scene chosen by **skin + time-of-day + sensed weather** (reuses `Aesthetic`, `DayGrade`, `SensedSignals`) |
| save into the keepsake | the assembled object + a rendered snapshot save into the **Daily Trace** (`痕迹`), persisted in SwiftData like every other record |

**It re-skins with the app** (Settings → 外观风格):

| skin | the little machine | Play scene |
| --- | --- | --- |
| **glass** (planetarium) | a brass-and-glass sky-craft | drifts under the stars, past the black hole |
| **ocean** | a folded paper boat / raft | floats over gentle water |
| **paper** | a pressed-paper folded toy | rolls along a garden path across a page |

Materials are the app's own vocabulary: **wood, paper, glass, brass, cloth,
light** — never chrome, never plastic.

---

## 1 · Design translation (the parts, the ratings, the scene)

### Parts by wish category
| category | part (glass-skin names) | material |
| --- | --- | --- |
| **recovery** | 软垫轮 · 稳定翼 (cushion wheel, stabilizer) | cloth + wood |
| **body / exploration** (walk) | 帆 · 弹簧腿 · 螺旋桨 (sail, spring-leg, propeller) | cloth + brass |
| **creation** | 发光引擎 · 火花核 (glowing engine, spark core) | brass + light |
| **connection** | 乘客灯 · 小灯笼 · 天线 (passenger light, lantern, antenna) | glass + light |
| **learning** | 罗盘 · 望远镜 · 地图鳍 (compass, telescope, map-fin) | brass + paper |
| **aesthetic** | 棱镜 · 风铃 (prism, wind-chime) | glass + cloth |

Which of a category's parts is chosen is seeded by a **stable hash of the seed
id** (same trick as the constellation / serendipity) so a wish always grows the
*same* part — your machine is *yours* and never reshuffles.

### Felt rating → how the part looks and moves
After a wish is completed, one gentle question — *刚才那件事，感觉怎么样?* —
with three soft answers (never a 1–5 star scale):

| felt | copy | part effect |
| --- | --- | --- |
| tiny but real | 「很小，但真的」 | small, faint glow, **no motor** (a quiet stabilizer-class piece) |
| felt good | 「挺好的」 | medium, warm glow, **gentle motor** (a working wheel/sail/spring) |
| changed my day | 「今天因此不一样了」 | large, bright glow, **strong motor** (an engine / rotor / star-core) |

The rating is **optional** and **skippable** → defaults to "tiny but real."
Rating maps to `partScale`, `glow`, `motorStrength` on the part.

### The Play scene (skin + time + weather)
`DayGrade.phase(hour:)` and `SensedSignals.weatherKind` pick the ~10 s scene:
morning → garden path · midday → through clouds · dusk → over water · late →
under the night sky. Rain tints it to a soft drizzle; clear opens the sky. The
craft moves with **gentle** motion (buoyancy / drift / a slow arc), never a
race. Reduce Motion → a still hero pose instead of the scene.

### Philosophy guardrails (non-negotiable, enforced in copy + code)
- **Never** "3/5 parts", a progress bar, a streak, an achievement, or "best day."
- A machine with **one** part is a **whole** little thing — the copy celebrates
  that it moved at all, never that it could be "more built."
- A **skipped** wish adds nothing *and takes nothing*; a **partial** adds a
  small quiet part (partial always counts).
- No sound effects that read as "reward dings" — at most the existing per-skin
  theme music swells softly during Play (`SkinMusic`).
- Runs through `ForbiddenWords.passes` on any generated copy, like every feature.

---

## 2 · Two decisions I need from you before CP-A

**Decision 1 — where it's built: native-first (recommended) vs web-first.**
The prompt says prototype in the web app (Three.js). But every feature you
actually use and test lives in the **native SwiftUI app on your iPhone**, and
that's where checkpoints can be demoed the way we've been working (build →
install over Wi-Fi → screenshot). The web app is paused (`main`, *core 43*).
**Recommendation: build native-first on `ios-aware`.** The web-first path is
still open if you'd rather validate the emotional loop in a browser first — say
the word and I'll re-plan for Three.js instead.

**Decision 2 — the renderer: SceneKit (recommended) vs SwiftUI-Canvas 2.5D.**
- **SceneKit** — genuine 3D parts that snap together with soft shadows and real
  physics for "Play"; ships with iOS, no dependency; the honest version of the
  concept. Risk: default SceneKit looks "gamey" → mitigated by deliberate
  material/lighting art direction (brass/glass/cloth, soft warm key light, no
  chrome). *Recommended.*
- **Canvas 2.5D** — layered parallax "fake-3D" in the same hand-drawn idiom as
  the black hole and constellation; lighter, warmer, but no true physics and the
  "Play" motion would be scripted, not simulated.

I'll assume **native + SceneKit** unless you say otherwise; both are reversible
early (the data model and rating flow are renderer-agnostic).

---

## 3 · Architecture (renderer-agnostic core + a rendering surface)

**Pure, testable core (Foundation-only, joins `Package.swift` + watch target):**
`DayToy.swift`
- `enum PartFeel { tinyButReal, feltGood, changedMyDay }` (Codable)
- `enum PartKind` (cushionWheel, stabilizer, sail, springLeg, propeller,
  engine, sparkCore, passengerLight, lantern, antenna, compass, telescope,
  mapFin, prism, chime) with `material`
- `struct DayPart: Codable { seedId, category, kind, feel, bornAt }`
  — `kind` chosen deterministically from `(category, seedId)`; `scale/glow/
  motor` derived from `feel`
- `struct DayObject: Codable { dateKey, parts: [DayPart], playedAt: String? }`
  — pure assembly logic (append a completion, cap at a calm number e.g. 8
  visible parts, layout slots) with unit tests
- `enum DayToyCopy` — the warm lines, philosophy-safe

**Persistence (SwiftData, matches the existing pattern):**
`DayObjectRecord` (payload-JSON hybrid, `profileID`-scoped, CloudKit-ready
shape — all defaults, no uniques, no relationships), + a rendered snapshot PNG
saved to Application Support and referenced by id. `AppStore` gains
`todayObject()`, `addPart(from:feel:)`, `markPlayed()`.

**Rendering surface (app target only):**
`DayToyScene.swift` — `SCNView` in a `UIViewRepresentable`, skin-aware base hull
+ materials, part attach animation, the Play timeline; reduce-motion still pose.
`BuildTodayView.swift` — the SwiftUI surface reachable from Home.

**Completion flow (`NowView`/`HomeView` `complete()`):** after a Complete/Partial,
present the felt rating; on answer, `store.addPart(...)`. Skipped adds nothing.

Everything obeys the house law: hard rules in code, LLM (if any copy) via
`@Generable` + fallback + `ForbiddenWords`; here the feature is mostly
deterministic, so little to no model dependence.

---

## 4 · Checkpoints (fixed demo points — each built, installed, screenshotted)

Each checkpoint is one or more `aware N:` commits, passes the green gate
(`swift test` + iOS build), is installed to your iPhone over Wi-Fi, and comes
with a screenshot. **I stop after each for you to look before continuing.**

| # | checkpoint | what you'll see on the phone | proof |
| --- | --- | --- | --- |
| **CP-A** | **Felt rating + data model** | Complete a wish → a soft *感觉怎么样?* card (很小但真的 / 挺好的 / 今天因此不一样了); the choice is recorded. Pure model + SwiftData landed, unit-tested. | screenshot of the rating card; `swift test` green |
| **CP-B** | **The stage** | A new surface from Home ("看看今天的小机器") shows the empty little craft, skin-aware, breathing gently in 3D. No parts yet. | screenshot in glass + ocean + paper |
| **CP-C** | **Parts attach** | Today's completions appear as parts by category, snapping on softly; felt rating drives size/glow. Complete one live → watch a part attach. | screenshot of a partly-built machine; short screen-recording |
| **CP-D** | **Play today** | 「今天让它动一下」 runs the ~10 s gentle scene by skin + time + weather; reduce-motion → still pose. | screen-recording of the Play scene |
| **CP-E** | **Keepsake** | After Play, the machine + a snapshot save into 痕迹; it persists across launches; tap a day to see its little machine. | screenshot of the trace card with the machine |
| **CP-F** | **Art + skins + a11y (polish)** | Full material art direction across all three skins, weather tint, soft music swell, VoiceOver labels, copy pass. | before/after screenshots per skin |

**MVP = CP-A … CP-E.** CP-F is polish. Stretch (not in this plan): share/export
the keepsake image, tap a part to recall which wish grew it, a weekly "little
fleet" of the week's machines.

Rough effort: CP-A ~½ day · CP-B ~½–1 day (first SceneKit surface) · CP-C ~1 day ·
CP-D ~1 day · CP-E ~½ day · CP-F ~1 day. Each is independently shippable and
revertible.

---

## 5 · Risks & how each is held
- **SceneKit reads gamey** → deliberate art direction (warm materials, soft
  shadows, no chrome, slow motion); CP-B is the go/no-go on the *look* before we
  invest in parts.
- **GPU cost next to the planetarium** → the toy is its **own surface**, not
  layered over the black-hole home; the home stays as-is.
- **Feeling like a checklist** → the copy pass (CP-F) and the "one part is whole"
  rule are load-bearing; a machine is never shown as incomplete.
- **watchOS weight** → the feature is **iPhone/iPad/Mac only**; the watch is
  untouched (no pbxproj additions there).
- **Snapshot storage growth** → one small PNG per day, pruned with the trace
  retention.

## 6 · Related open item (separate, not part of this)
You flagged that **今日痕迹 shows generated text** ("你让脑子里多了一点新的
东西") rather than what you actually did. That's `TraceGenerator.generateText`
producing a soft default line. It's a **separate quick fix** — the cleanest
options: (a) make the completion flow invite *your own words first* and treat the
generated line as an editable placeholder, or (b) let the new felt-rating +
part feed a more personal, less canned line. I can do this in one small commit
before or after CP-A — tell me which you'd like.

---

## 7 · Working protocol (unchanged)
Native-first on `ios-aware`; each green checkpoint committed as `aware N: …`
(Co-Authored-By trailer), pushed to the `ios-aware`/`ios-glass`/`macos` trio,
installed to your iPhone (and Ruby's / the iPad when reachable), screenshotted.
I pause after every checkpoint for your look before starting the next.
