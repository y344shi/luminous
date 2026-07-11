# Luminous — Architecture & Context (the onboarding brain)

> One file to bring any agent (or human) up to speed with **no prior context**:
> what we're building and why, the ideals we never break, the stack, the data
> structures, the architecture, the languages, and how we work. Read this first,
> then `README.md` for the feature tour and `CLAUDE.md` for the working rules.
>
> Last brought current: **2026-07-11**. If you change architecture, update this.

---

## 1. What this is (and what it is NOT)

**《今天别消失》 / "Today Don't Disappear"** is an AI **life-anchor** app, native
SwiftUI across **iOS · iPadOS · macOS · watchOS**. It catches a soft wish (a
*Seed*) and hands it back at the *right moment* so that today didn't completely
disappear.

It is **NOT** a todo / productivity app. This is the single most important thing
to internalize. There are:

- **no deadlines, no streaks, no priorities, no percentages, no scores, no shame.**
- **Partial always counts. A skipped wish never "disappears" and is never punished.**
- The AI **never commands, never diagnoses, never professes love, never pushes
  all-night work.** It offers; it does not push.

If a change would make the app feel like it's keeping score or nagging, the change
is wrong — revert it. The emotional contract beats the feature.

**Read `../docs/product-philosophy.md` before touching tone or copy.**

---

## 2. The core loop (must NEVER break)

```
Add a Seed  →  a Now opportunity  →  Complete / Partial / Skipped  →  a Daily Trace
   /add          /now (现在别消失)         (partial always counts)         (痕迹)
```

Code path: `AddSeedView` → `AISeedParser`/`SeedParser` → `AppStore` →
`NowView` → `ContextBuilder` (SemanticTime.swift) → `Scoring.recommend` →
`AppStore.addTrace`. Everything else in the app orbits this spine.

---

## 3. Stack, languages, platforms

| Layer | Choice |
| --- | --- |
| **Language** | Swift 6 (files compile in Swift-5 language mode via `swiftLanguageMode(.v5)` in the test package; the app target is default-MainActor). |
| **UI** | SwiftUI, one multiplatform Xcode project (`SDKROOT=auto`). `@Observable` (Observation framework), `@Environment` for the store/router/theme. |
| **Persistence** | **SwiftData** (`@Model`) on iOS/iPadOS/macOS; **UserDefaults** on watchOS. CloudKit-sync-ready shape (compile-gated, needs paid dev program). |
| **On-device LLM** | Apple **FoundationModels** (`@Generable`, iOS/macOS 26 / Apple Intelligence). Private, free, offline. **Unavailable in the Simulator** → every LLM path degrades to a deterministic fallback there. |
| **Vision/OCR** | Apple **Vision** (text recognition for the photo translator). |
| **Handwriting** | **PencilKit** (`PKCanvasView`, `PKDrawing`) — iPad/Pencil-centric, iOS-gated. |
| **3D** | **SceneKit** (the day-object machine 今天的小机器) — `SceneView`, `SCNRenderer`. |
| **Maps/geo** | **MapKit** (`MKLocalPointsOfInterestRequest`, `MKDirections`), **CoreLocation** (coarse, whenInUse), **CLGeocoder**. |
| **Motion/sensors** | **CoreMotion** (accelerometer → activity), mic loudness (coarse, never recorded), HealthKit arousal (gated, needs paid program). |
| **Weather** | open-meteo (only a **coarsened** home coordinate ever leaves the device). |
| **Audio** | AVFoundation ambient session (per-skin theme music, CC-BY). |
| **Web sibling** | The repo is a monorepo; the **root** is the original Next.js/React web app (`@luminous/core`, `app/`, `components/`, `lib/`, `packages/`, `prisma/`). The native app is a faithful port of that framework-free core. Many files say "ported from lib/…". |

The web app runs `npm run typecheck && npm test && npm run build`. The native app
runs the **green gate** (§6). Product logic is mirrored between them.

---

## 4. Repository & branch topology (READ THIS — it has bitten people)

One git repo, **monorepo**: web app at the root, native app under `ios/`.

**Branches (as of the 2026-07 consolidation): exactly two.**

| Branch | Role | Where it's checked out |
| --- | --- | --- |
| **`main`** | canonical "net" trunk — web + iOS, everything | `wt-aware/` worktree (the non-live build area) + remote |
| **`ios-glass`** | the "ios" branch the **live Xcode copy** tracks | `Luminous/net/luminous/` (the live copy) + remote |

Both point at the same commit and are kept in lockstep. `ios-aware` and `macos`
were retired in the consolidation (they were identical mirrors of the trunk;
`ios-aware` was the old integration branch name). An archive branch
**`stashed_history`** (local-only) holds pre-consolidation local edits.

### ⛔️ The hard rule that has broken the workstation

**NEVER switch branches / merge / rebase / stash / checkout that rewrites files
under the worktree Xcode currently has OPEN.** It corrupts Xcode's project + index
state. Concretely:

- The **live Xcode copy is `Luminous/net/luminous` on `ios-glass`.** Do read-only
  git there (`status`/`log`/`diff`/`ls-files`) freely; never rewrite its files
  while Xcode is open.
- Do agent work in **`wt-aware/`** (on `main`), which is never open in Xcode.
- To move the live copy forward: **ask the user to close Xcode**, confirm a clean
  tree, then `git -C net/luminous merge --ff-only origin/ios-glass`, reopen.
- Multi-direction work → a **separate `git worktree` per branch**, only one open
  in Xcode at a time.

### The push habit

Work lands on the trunk, then is mirrored so `main` and `ios-glass` stay equal:
```
git push origin main
git push origin main:ios-glass      # (or commit on ios-glass and push main from it)
```
(Historically the "trio" was `ios-aware → ios-glass → macos`; now it's just the two.)

---

## 5. Xcode target membership (silent-breakage trap)

Xcode **synchronized file groups**: a new `.swift` file under `Luminous/`
**auto-joins the iOS/mac app target** — but **NOT**:

- the **watch target** (explicit FACE-UUID refs in `project.pbxproj`), and
- the **SwiftPM test package** (`Package.swift` `sources:` list).

Consequences you must handle by hand:

1. A **new pure (Foundation-only) file** that you want unit-tested → add one line
   to `Package.swift` `sources:`.
2. A **watch-shared file** (Store/Scoring/Domain/…) that gains a new type
   dependency → add that dependency file to the watch target's pbxproj refs, or
   **the watch build breaks silently** (the app + tests stay green).

---

## 6. Build / verify — the green gate (every change)

```bash
# 1. fast pure-core gate (SwiftPM package; NEVER touches Luminous.xcodeproj)
cd ios && swift test            # 80+ tests: late-night gate, classifiers, plans, sims…

# 2. the iOS app
xcodebuild -scheme Luminous -project Luminous.xcodeproj -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# 3. at milestones, also:
xcodebuild -scheme Luminous -project Luminous.xcodeproj -destination 'platform=macOS' build
xcodebuild -scheme "Luminous Watch App" -sdk watchsimulator build
```

Rules of the gate: **one narrow green improvement per change; revert rather than
leave the tree red or dirty.** If a change can't go green, ship a smaller slice
and log why. FoundationModels/PencilKit/SceneKit features render/degrade in the
Simulator but are **verified on a physical device** (Apple Intelligence + Pencil
+ real GPU/sensors only exist there).

---

## 7. Architecture at a glance (three rings)

```
        ┌─────────────────────────────────────────────────────────────┐
        │  VIEWS (SwiftUI)  — HomeView, tabs, sheets, the skins         │
        │  glass planetarium · ocean liquid · paper list · hub · deck   │
        └───────────────▲───────────────────────────▲──────────────────┘
                        │ reads @Observable state    │ calls
        ┌───────────────┴──────────┐   ┌─────────────┴──────────────────┐
        │  AppStore (@Observable)  │   │  App-only intelligence (LLM)   │
        │  the single glue; every  │   │  @Generable + fallback +       │
        │  persisted write goes    │   │  ForbiddenWords. Uses MapKit,  │
        │  through a save-seam     │   │  Vision, CoreLocation, etc.    │
        └───────────────▲──────────┘   └─────────────▲──────────────────┘
                        │                             │ every signal is
        ┌───────────────┴─────────────────────────────┴──────────────────┐
        │  PURE CORE (Foundation-only, unit-tested by `swift test`)       │
        │  Scoring (the spine) · Domain · SeedParser · SemanticTime ·     │
        │  SensorClassifiers · Rhythm · Places · Recurrence · Mentality · │
        │  Nudge(gate) · PlanKit · Suggestion · Tags · OceanSim ·         │
        │  PlanetPhysics · DayToy · Copy(ForbiddenWords) · LateNightCare  │
        └────────────────────────────────────────────────────────────────┘
```

**The architecture law (pinned by tests):** the **linear scorer** (`Scoring.swift`)
is the auditable spine. Every intelligence source — sensors, places, history,
mentality, the LLM — contributes **exactly one clamped additive term**. Hard
safety gates (late-night) live in **code, never prompts**. Tests fail if that
ever changes.

---

## 8. The scoring spine (the heart — `Scoring.swift`)

`Scoring.scoreSeed(seed, ctx, rng?, history?, mentality?)` produces a
`ScoreBreakdown`. The base is a **weighted linear blend of clamped 0–1 fits**,
then **additive clamped bonus terms**, then the late-night gate:

```
base   = timeFit*0.20 + durationFit*0.20 + energyFit*0.20 + locationFit*0.20
       + moodFit*0.10 + freshness*0.05 + serendipity*0.05
total  = base
       + triggerBonus(seed, ctx)          // trigger conditions vs live context
       + sensorBonus(seed, ctx)           // motion/loudness/arousal  (clamp ±0.25)
       + placeBonus(seed, ctx)            // a fitting place within a short walk (+0.12), late-night-gated
       + Recurrence.historyBonus(...)     // natural cadence / fit-learning (clamp ±0.15)
       + Mentality.bonus(...)             // day's mood estimate (clamp ±0.20), never shown as a label
       + (isLateNight && isRescueSeed ? 0.5 : 0)
total  = clamp(total, 0, 2)
```

Key properties:
- **`rng`-injectable** and deterministic in tests. `serendipity` uses
  `stableSerendipity(seedId, partOfDay)` so two opens a minute apart agree, but a
  different part of the day differs (no jitter between opens).
- **Late-night is a HARD safety gate**, not a weight: `rankSeeds` filters out
  `isUnsafeLateNight` seeds when `ctx.isLateNight` (never recommends going
  out / high-energy / long / exploration late at night), and surfaces
  stop-loss/rescue seeds instead (`+0.5`). `buildReason` swaps to the gentle
  late-night copy. **This gate is code, never a prompt.**
- To add a new intelligence signal: write a pure function returning a **clamped
  additive term**, add it to `scoreSeed`, and unit-test it. Do not add weights to
  the base blend without care; do not route safety through the LLM.

`rankSeeds` → top-N `ScoredSeed`; `recommend` → `Opportunity` records for the UI.

---

## 9. The on-device LLM pattern (every AI feature obeys this)

The house law, enforced everywhere (the `LearningMerge` / `PursuitMerge` pattern):

1. **`@Generable` structured output** — the model fills a typed struct with
   `@Guide` field constraints (tone rules as hard instructions). Never free text
   we parse by hand.
2. **Deterministic fallback** — a keyword/heuristic path that runs when the model
   is unavailable (always true in the Simulator) so the feature never comes up
   empty. The LLM *enriches*; it is never *required*.
3. **`ForbiddenWords.passes(...)`** (in `Copy.swift`) post-filters anything shown
   to the user — the forbidden-words list is the copy safety net (no todo/shame
   language).

> **The LLM decides content; the code decides truth and safety.** Gates, clamps,
> and the forbidden-words filter are never delegated to a prompt.

App-only LLM features (each degrade-safe): `AISeedParser` (raw wish → full draft),
`TaskPlannerAI`+`PlanKit` (2–4 tiny steps with real resources), `AILesson`
(vocab content for a learning wish), `MentalityAI`+`Mentality` (day mood → ±0.2
tilt), `SuggestAI` (reason-writer + moment suggestions), `SituationCare`
(late-night place read), `WeekReview` (one warm weekly paragraph), `LearningLog`
(is this the same pursuit? merge vs spawn), `RecipeExecutor` (dish → ingredient
checklist → nearest market), `Translate*` (photo → EN+中文), `ExecutorViews`
(review quiz / creation spark / connection draft / recovery breath).

---

## 10. Data model (domain types — `Domain.swift`)

All `Codable`/`Hashable`; ids via `DomainUtil.uid(prefix)`; dates as ISO strings
or `YYYY-MM-DD` local `dateKey`.

**Enums:** `SeedCategory` (body, creation, connection, exploration, recovery,
learning, aesthetic) · `Energy` (low/medium/high) · `Mood` (empty, tired, anxious,
okay, alive, avoidant, lonely, wantLove, unknown) · `SemanticTime` (morning, lunch,
afternoon, afterWork, evening, lateNight, weekend, transit) · `LocationType`
(anywhere, home, work, outdoor, downtown, computer, transit, unknown) · `SeedStatus`
(active, sleeping, completed, archived) · sensed: `Activity` (still/walking/transit),
`Ambient` (quiet/lively), `Arousal` (calm/elevated), `WeatherKind`
(clear/clouds/rain/snow/fog/unknown), `PlaceKind` (cafe, library, park, market,
store, restaurant, gym, museum, attraction, nature) · `ThemeName` (warmPaper,
duskGarden, minimalIos, fieldNotebook, softRitual).

**Core structs:**
- **`Seed`** — a wish: `rawText`, `title`, `categories[]`, `minimumAction`
  (deliberately tiny), `estimatedDurationMin`, `energyRequired`, `locationType`,
  `preferredTimes[]`, `triggerConditions[]`, optional `tags[]`, `status`, timestamps.
- **`ContextSnapshot`** — the moment: `semanticTime`, `mood`, `energy`,
  `freeMinutes?`, `isLateNight`, `isWeekend?`, `isOutdoorWeatherGood?`,
  `locationHint?`, plus sensed `activity?/ambient?/arousal?/weatherKind?` and
  `nearbyKinds?` (all optional → degrade to nil).
- **`Opportunity`** — a scored recommendation: `seedId`, `score`, `reason`,
  `suggestedAction`, `notificationText`.
- **`DailyTrace`** — a kept moment (痕迹): `date`, `seedId?`, `text`, `category?`,
  `partial?`. Partial and skipped both leave a trace.
- **`PursuitNote`** — one thought on a pursuit's 手帐 page: `kind`
  (note/idea/aiIdea/**sketch**), `text`. For `.sketch` the text is a **base64
  PKDrawing** (handwriting; no schema change).
- **`DayObject` / `DayPart`** (`DayToy.swift`) — 今天的小机器: each completed wish
  grows ONE `DayPart` (kind + material + felt rating → derived `scale`/`glow`/
  `motor`); `DayObject` holds today's parts + optional `keptAt`/`snapshot` (PNG).
- **`Settings`** — theme, aiMode, quietHours, maxRemindersPerDay, `nudgesEnabled`
  (default **false**).

`DomainUtil`: `uid`, `nowIso`, `localDateKey`, `clamp`, `friendlyDate`
(今天/昨天/前天/M月D日).

---

## 11. Persistence (`Persistence.swift`) & the store (`Store.swift`)

**`AppStore` (`@Observable`)** is the single stateful glue (analogue of the web
Zustand store). Views read its published state (`seeds`, `traces`, `settings`,
`aesthetic`, `opportunities`, `mentality`, …) and call its methods. **Every
persisted write goes through a save-seam** that dual-writes (see below). Public
surface includes: `addSeed/updateSeed/setSeedStatus`, `addTrace/updateTrace/
removeTrace`, `notes(for:)/addNote/removeNote` (`noteBump`), `todayObject/addPart/
keepToday` (`toyBump`), `setTheme/setAesthetic/setAestheticAuto/setSenseAround/
setMusicOn`, gardens (`createGarden/switchGarden`, `gardens`), learning
(`addLearnedWords/logLearning/mergeLearningSeed`), `logEvent`, `seedHistory`,
`learnedPlaceCells`, `effectiveAesthetic(dark:)`.

**SwiftData layer** (iOS/iPadOS/macOS; watch uses UserDefaults, `#if os(watchOS)`):
- **Hybrid records** — a few queryable columns + a `payload` JSON blob of the
  existing Codable struct. **The structs stay the domain currency; struct
  evolution never migrates the schema** (add optional fields freely — old
  payloads decode loss-free; this is how `.sketch` notes and `DayObject.keptAt/
  snapshot` were added with zero migration).
- **`@Model` records:** `ProfileRecord`, `SeedRecord`, `TraceRecord`,
  `LearningRecord`, `NoteRecord`, `DayObjectRecord`, and the append-only
  **`EventRecord`** (timestamp, kind, payloadJSON, contextJSON) — the life-event
  log that Rhythm/Recurrence/Places read.
- **Multi-profile** ("gardens", Settings → 花园): every record is `profileID`-scoped;
  CloudKit rules honored (defaults everywhere, no `.unique`, no relationships).
- **Migration** `migrateFromUserDefaultsIfNeeded`: imports old `tdd.*` keys into a
  default profile once; **never deletes the `tdd.*` keys** (dual-write =
  loss-free rollback path).

---

## 12. Awareness (coarse, on-device, opt-in — `Sensors.swift` + the event log)

Sensing is **split in two** so the rules stay testable:
- **`SensorClassifiers.swift`** (pure, in the test package) — the classification
  thresholds (motion → activity, weather → kind, good-outdoor). Pinned by tests.
- **`Sensors.swift`** (`SensedSignals`, `@Observable`, app-only) — the platform
  samplers: CoreMotion, coarse CoreLocation → open-meteo weather + `MKLocalPoints
  OfInterestRequest` nearby places (**kind-diverse**: shops never crowd out
  parks/attractions/nature), reverse-geocoded place label, nearest transit,
  compass heading.

Derived, still coarse:
- **`Places.swift`** (pure) — location fixes are coarsened to ~150 m **grid cells**
  the instant they arrive; **only the cell key is ever logged, never a raw
  coordinate**; events age out at 90 days. Home = modal night cell, work = modal
  weekday-day cell → feeds `locationHint`.
- **`Rhythm.swift`** (pure) — turns the event log's state transitions into dwell
  time (minutes per state today, hour-of-week histogram).
- **`Recurrence.swift`** (pure) — learns each wish's natural cadence + favorite
  hour + where it keeps not fitting → `historyBonus` (±0.15). Never a streak,
  never punitive, never displayed. Sleeping wishes resurface at their cadence.
- **`Mentality.swift` / `MentalityAI.swift`** — day aggregates → three soft dials
  → one clamped ±0.2 scoring tilt. Never shown as a label (no implied diagnosis).

**Privacy invariants:** only coarse context ever leaves the device (a coarsened
home coord for weather); no GPS trails, no biometrics, no raw audio. Sensing is
opt-in (`senseAround`).

---

## 13. The three skins (Home branches by skin; only glass is "planetary")

`AppStore.effectiveAesthetic(dark:)` → `Aesthetic` (glass / ocean / paper). The
Home top bar has an always-visible **skin switcher** (`HomeView.skinSwitcher`).

- **glass — the planetarium** (`HomeView` + `OrbitSim` + `PlanetPhysics` +
  `ConstellationSky`): wishes orbit a rendered black hole on a **velocity-Verlet
  gravity simulation**; device tilt is a real transient force vs a self-learned
  rest pose. `PlanetPhysics.swift` (pure, tested) is the math: importance→mass/
  size (heavier/important = bigger, closer to the glass), vis-viva capture of
  important off-schedule wishes (they "flee in" and are caught), like-type
  attraction, moons. Every `DailyTrace` is a permanent **star** (记忆星座);
  completing a wish plays the birth ceremony (infall → ring flare → jet → bloom).
  Context-born **shooting stars** carry suggestions; the **scout** pairs an active
  wish with a fitting nearby place.
- **ocean — a literal liquid** (`OceanField` + `OceanSim`): a 2D **buoyancy**
  field; a wish's bubble grows with relevance and floats toward a rest depth set
  by that relevance (more relevant = bigger = floats higher); the gyro sloshes it;
  pairwise separation; clamped to the visible water. `OceanSim` is pure + tested.
- **paper — a calm list** (`PaperField` backdrop + `HomeView.wishListField`):
  wishes as warm **note-cards** (ruled left margin) in recommendation order. No
  physics.

`SceneBackground.swift` grades glass/ocean by real time-of-day (sky, sun/moon,
water). `AestheticField.swift` picks the backdrop. Reduce Motion stills every sim.

---

## 14. Feature surfaces (where things live)

- **Tabs** (`RootView`, `AppRouter`): 今天 `HomeView` · 愿望 `GardenView` (seed
  garden + `SeedDetail` → `PursuitPageView`) · 痕迹 `TracesView` (+ `WeekReview`) ·
  设置 `SettingsView`.
- **Home bottom bar**: quick-access 拍照翻译 (`TranslateView`) + 添加 (`AddSeedView`)
  + a **去处 hub** button (`LinkHubView`) that links 愿望日历 · 手帐 · 今天的小机器 ·
  痕迹 into one connected space.
- **现在别消失** (`NowView`): context → opportunities → completion → trace.
- **今天的小机器 / Build Today** (`BuildTodayView` + `DayObjectStage` +
  `DayObjectSnapshot` + `DayCraftArt` + `DayToy` + `FeltRatingView`): a SceneKit
  day-object. Each completed wish (with an optional felt rating: 很小但真的 / 挺好的
  / 今天因此不一样了) grows ONE part; **播放今天** plays a gentle ~10 s scene by
  hour+weather; **收进今天的痕迹** renders a PNG keepsake into 痕迹. Count-free — a
  machine with one part is a WHOLE little thing.
- **手帐 notes** (`PursuitPage`): a **click-through card deck** — each thought a
  card (note/idea/aiIdea/**sketch**) with an add card; **Apple Pencil** handwriting
  via `PencilNote` (`.sketch` kind, iOS-gated, degrades off-iOS). The on-device
  model reads the page and suggests where the pursuit could grow.
- **愿望日历** (`WishCalendarView`): a calendar-stack of every on-device wish, seven
  weekday piles that split open like a finger in a book; today highlighted. "不是
  日程" — a look-back, never a schedule. Reachable from the hub and Settings.
- **Late-night care** — glass: `LateNightCareOrbit` (guiding stars that orbit and
  point the way home); ocean/paper: `LateNightCareStrip` (a compact top strip);
  openers shared via `LateNightActions`; the situational read is `SituationCare`.
  The gate + safety copy are **code-owned**.
- **Plans & executors** (`PlanView`/`PlanKit`/`TaskPlannerAI`, `ExecutorViews`,
  `RecipeExecutor`, `RouteFinder`, `Translate*`): tiny steps carrying real
  resources; all **offers**, never auto-run.
- **Notifications** (`Nudge`): wired but **OFF by default**; `NudgeGate` (pure,
  tested) — never in quiet hours, never late at night, never over the daily cap,
  one pending at a time.

---

## 15. File index (68 app files + 11 test files)

**Pure core (in `Package.swift`, unit-tested):** `Domain` `Scoring` `SeedParser`
`SemanticTime` `Copy`(+`ForbiddenWords`) `SensorClassifiers` `Rhythm` `Places`
`Recurrence` `Mentality` `Nudge`(gate) `PlanKit` `Suggestion` `Tags` `OceanSim`
`PlanetPhysics` `DayToy` `LateNightCare`.

**App state / glue:** `Store` (AppStore) · `Persistence` (SwiftData) · `RootView`
(shell+tabs) · `LuminousApp` · `ContentView` (thin alias).

**App-only intelligence (LLM):** `AISeedParser` `TaskPlannerAI` `AILesson`
`MentalityAI` `SuggestAI` `SituationCare` `LearningLog` `RecipeExecutor`
`WeekReview` `Translate` (Vision+LLM).

**Views / scene:** `HomeView` `GardenView` `NowView` `TracesView` `SettingsView`
`AddSeedView` `PursuitPage` `WishCalendarView` `LinkHubView` `BuildTodayView`
`FeltRatingView` `PlanView` `ExecutorViews` `OpportunityCard` `TranslateView`
`WeekReview`.

**Skins / sims / render:** `Aesthetic` `AestheticField` `SceneBackground`
`SkinMusic` · `OrbitSim` `ConstellationSky` (glass) · `OceanField`/`OceanSim`
(ocean) · `PaperField` (paper) · `DayObjectStage` `DayObjectSnapshot` `DayCraftArt`
(machine) · `PencilNote` (handwriting).

**Late-night care:** `LateNightCare`(pure) `LateNightCareOrbit` `LateNightCareStrip`
`LateNightActions`.

**Design system:** `Theme` (tokens) `DesignKit` `Copy` `Feedback` (haptics)
`SemanticTime` `DayGrade` (time-of-day palette).

**Sensing:** `Sensors` (`SensedSignals`) `SensorClassifiers` `RouteFinder`.

**Tests (`CoreTests/`):** `CoreTests` (loop + late-night gate + classifiers +
parser + traces), `DayToyTests`, `MentalityTests`, `NudgeGateTests`,
`OceanSimTests`, `PlacesTests`, `PlanetPhysicsTests`, `PlanKitTests`,
`RecurrenceTests`, `RhythmTests`, `ScoutTests`.

---

## 16. Conventions, habits & strategies

- **Committed history is a rule.** Every change — however small — is committed on a
  named branch after it goes green, with a clear subject and the trailer
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`. Never
  leave work loose in the tree; revert what can't go green.
- **Single-quote `git commit -m`** (message bodies contain backticks/CJK that zsh
  would otherwise command-substitute).
- **One narrow improvement per cycle.** Never rewrite wholesale. If a big change
  risks the gate, ship a smaller slice and **log the reduction** in a decisions
  file.
- **Tracking docs.** Multi-cycle work uses a `*-PLAN.md` + `*-WORKLIST.md` +
  `*-DECISIONS.md` trio (see `WORKLIST.md`, `OVERNIGHT-DECISIONS.md`,
  `NIGHT2-*.md`). Decisions taken autonomously are recorded there for review.
- **Copy discipline.** Warm, gentle, never shaming; never todo-app words
  (`Copy.forbiddenWords`). Chinese-first UI copy; the app's voice offers, never
  commands.
- **Naming / idiom.** Match the surrounding file's comment density and style. File
  header comments describe purpose + which layer the file belongs to; keep them
  accurate. New pure file → add to `Package.swift`; watch-shared file with a new
  dep → add to the watch pbxproj refs.
- **Deferred (needs the paid Apple Developer Program, $99/yr):** CloudKit **sync**
  (schema is ready; compile-gated), **HealthKit** arousal, **TestFlight**. Also
  logged as future: per-skin craft hulls for the machine, per-word spaced
  repetition, watch App Group sync, persist-the-moon-map.

---

## 17. Glossary (Chinese terms you'll meet)

| Term | Meaning |
| --- | --- |
| 《今天别消失》 | "Today Don't Disappear" — the app |
| 今天 / 愿望 / 痕迹 / 设置 | the four tabs: Today / Wishes / Traces / Settings |
| 现在别消失 | "Don't-disappear-right-now" — the Now opportunity flow |
| 种子 (Seed) / 愿望 (wish) | a soft intention the user caught |
| 痕迹 (trace) | a kept moment of presence (not an achievement) |
| 手帐 | a pursuit's journal page (notes/ideas), NOT a task board |
| 今天的小机器 | "today's little machine" — the day-object you assemble |
| 记忆星座 | "memory constellation" — traces as permanent stars |
| 愿望日历 | the wish calendar (a look-back, 不是日程 = not a schedule) |
| 去处 | "places to go" — the LinkHub |
| 玻璃 / 海面 / 纸页 | the three skins: glass / ocean / paper |
| 花园 (garden) | a profile (multi-profile switcher) |
| 深夜 | late night — the hard safety gate |

---

*If you're an agent picking this up cold: work in `wt-aware` on `main`, never
rewrite the live copy while Xcode is open, keep the scorer the spine and every new
signal one clamped term, gate safety in code, give every LLM a fallback + forbidden-
words filter, run the green gate, commit small, and never make it feel like a todo
app.*
