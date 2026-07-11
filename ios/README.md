# 《今天别消失》 — native app (iOS · macOS · watchOS)

The SwiftUI implementation of the **AI life-anchor** (read
[`../docs/product-philosophy.md`](../docs/product-philosophy.md) first — it is not
a todo app). One Xcode project, four platforms (iOS · iPadOS · macOS · watchOS),
one pure core, and an **on-device LLM** (Apple FoundationModels) doing the
intelligent parts — nothing about you ever leaves the phone.

> **New here / an agent with no context?** Read **[`ARCHITECTURE.md`](ARCHITECTURE.md)**
> — the full onboarding brain: goals, ideals, stack, data structures, the scoring
> spine, persistence, branch topology, and how we work. This README is the feature
> tour on top of it.

## The core loop (never breaks)
**Add a Seed → a Now opportunity → Complete / Partial / Skipped → a Daily Trace.**
Partial always counts; skips never shame; late night is a hard safety gate.

## What the native app can do (2026-07 state)

**Three real skins** — the Home layout branches by skin (always-visible switcher
in the top bar), and only glass is "planetary":
- **glass** — the planetarium below (physics-real).
- **ocean** (`OceanField`/`OceanSim`) — a literal **liquid**: a wish's bubble
  grows with relevance and floats toward a rest depth set by that relevance; the
  gyro sloshes the water; small wishes stay reachable.
- **paper** (`PaperField`) — a calm ruled-notebook **list** of warm note-cards in
  recommendation order. No physics.

**今天的小机器 / Build Today** (`BuildTodayView` + `DayObjectStage` + `DayToy`) — a
**SceneKit** day-object: each completed wish (with an optional felt rating) grows
ONE part (shape by kind, size/glow/motor by how it felt); **播放今天** plays a
gentle ~10 s scene by hour+weather; **收进今天的痕迹** renders a PNG keepsake into
痕迹. Count-free — one part is a whole little thing.

**手帐 notes as a card deck + Apple Pencil** (`PursuitPage` + `PencilNote`) — each
thought is a click-through card (note / idea / ai-idea / **handwritten sketch** via
PencilKit); the on-device model reads the page and suggests where the pursuit can
grow. **愿望日历** (`WishCalendarView`) and a **去处 hub** (`LinkHubView`) tie
calendar · 手帐 · 小机器 · 痕迹 into one connected space, reachable from Home.

**The planetarium home (glass skin)** — a physics-real scene:
- Wishes orbit a rendered **black hole** (event-horizon shadow, lensed accretion
  disk, photon ring, Doppler beaming — `PLANETARIUM-PHYSICS.md`) on a
  velocity-Verlet **gravity simulation** (`OrbitSim.swift`); device tilt is a real
  transient force against a self-learned rest pose.
- **记忆星座** (`ConstellationSky.swift`): every trace is a permanent star, placed
  by stable hash, tinted by category, joined into the week's faint constellation.
  Completing a wish plays the birth ceremony: infall → ring flare → jet → bloom.
- Context-born **shooting stars** carry suggestions; the **scout** pairs an active
  wish with a fitting place within a short walk ("图书馆 200m").

**On-device intelligence (FoundationModels, iOS 26 / Apple Intelligence)** — every
feature follows one law: *@Generable structured output + deterministic fallback +
ForbiddenWords filter; the LLM decides content, code decides truth and safety*:
- **Seed parser** (`AISeedParser`) — a raw wish → categories, tiny minimum action,
  duration, energy, place, times (keyword parser as the net).
- **Task breakdown** (`TaskPlannerAI` + `PlanKit`) — 2–4 tiny steps, each carrying
  a live resource: a nearby place with a **real walking route** (`RouteFinder`,
  MKDirections), a themed vocab set, the camera translator, a breath.
- **Deep assists** (`ExecutorViews`, `RecipeExecutor`) — vocab picker & review quiz,
  photo → EN+中文 translation (`Translate*`), creation opening line, connection
  first sentence (copy-only), and the recipe provisioner: dish → ingredient
  checklist → nearest market with walking route.
- **Mentality estimate** (`MentalityAI` + `Mentality`) — the day's aggregates →
  one clamped ±0.2 scoring tilt; never shown as a label.
- **Reason-writer & moment suggestions** (`SuggestAI`), **weekly review**
  (`WeekReview`), **pursuit merge** (`LearningLog`) — all bounded the same way.

**Awareness (coarse, on-device, opt-in)** — `Sensors.swift` + the event log:
- Motion (CoreMotion), coarse location → weather (open-meteo) + nearby places
  (MapKit, **kind-diverse**: shops never crowd out parks/attractions/nature).
- **Learned home & work** (`Places.swift`): ~150 m grid cells, modal night/day —
  raw coordinates are never stored.
- **Life-event log + rhythm** (`Persistence` EventRecord + `Rhythm.swift`): dwell
  histograms, 90-day raw retention; **recurrence** (`Recurrence.swift`) lets
  sleeping wishes resurface at their natural cadence and quietly learns which
  contexts a wish keeps not fitting (never punitive, never displayed).

**Storage** (`Persistence.swift`) — SwiftData, multi-profile ("gardens", Settings →
花园), payload-JSON hybrid records, CloudKit-sync-ready shape; migrated from the
old UserDefaults keys which are kept dual-written as a rollback. The watch stays
on UserDefaults.

**Notifications** (`Nudge.swift`) — wired but **OFF by default**; quiet hours,
daily cap, and the late-night rule is absolute (深夜永远不会打扰，这条规则改不了).

## Build / verify

```bash
# fast green gate — pure core tests (SwiftPM package, never touches the .xcodeproj)
cd ios && swift test                # 80+ tests: safety gates, classifiers, plans, sims…

# the apps
xcodebuild -scheme Luminous -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -scheme Luminous -destination 'platform=macOS' build
xcodebuild -scheme "Luminous Watch App" -sdk watchsimulator build
```

Device install (free Personal Team, over Wi-Fi, phone unlocked):
`xcodebuild … -sdk iphoneos -destination 'generic/platform=iOS'
DEVELOPMENT_TEAM=<team> -allowProvisioningUpdates build`, then
`xcrun devicectl device install app --device <udid> <path>/Luminous.app`.

Simulator note: FoundationModels features silently fall back in the Simulator
(no Apple Intelligence there) — LLM paths are verified on a physical device.
`-demoStars` (DEBUG launch argument) seeds demo traces to present the constellation.

## Layout

| where | what |
| --- | --- |
| `Luminous/` | app sources — Xcode synchronized group, new files auto-join the app target |
| `LuminousWatch/` | the watch app (shares the pure core via explicit pbxproj refs) |
| `Package.swift` + `CoreTests/` | the SwiftPM test harness for the pure core (`swift test`) |
| pure core (also in the test package) | `Domain` `Scoring` `SeedParser` `SemanticTime` `Copy` `SensorClassifiers` `Rhythm` `Places` `Recurrence` `Mentality` `Nudge`(gate) `PlanKit` `Suggestion` |
| app-only intelligence | `AISeedParser` `TaskPlannerAI` `MentalityAI` `SuggestAI` `AILesson` `LearningLog` `Translate*` `RecipeExecutor` `ExecutorViews` `PlanView` `WeekReview` |
| scene | `HomeView` `OrbitSim` `ConstellationSky` `AestheticField` `SceneBackground` `SkinMusic` |

## The architecture law (pinned by tests)

The linear scorer (`Scoring.swift`) is the auditable spine. Every intelligence
source — sensors, places, history, mentality, LLM — contributes **one clamped
additive term**. Hard gates (late-night) live in **code, never prompts** — three
tests fail if that ever changes. Every LLM feature has a deterministic fallback
and its output passes `ForbiddenWords`.

## Docs in this directory
- **`ARCHITECTURE.md` — the onboarding brain: goals, ideals, stack, data
  structures, scoring spine, persistence, branch topology, conventions. Start
  here if you have no context.**
- **`TOUR.md` — the illustrated tour: every function mapped to what it draws,
  with diagrams and screenshots.**
- `CLAUDE.md` — working rules (branch safety, build commands).
- `WORKLIST.md` / `OVERNIGHT-DECISIONS.md` / `NIGHT2-*.md` — the running trackers +
  decision logs for the autonomous build sessions.
- `BUILD-TODAY-PLAN.md` — the 今天的小机器 (day-object) design + checkpoint plan.
- `VISION-AUDIT.md` — the product/architecture audit + build order (largely shipped).
- `OVERNIGHT-SESSION.md` — the "aware" overnight build record + decisions.
- `PLANETARIUM-PHYSICS.md` — the black hole / orbit / meteor physics notes.
- `MUSIC-CREDITS.md` — per-skin theme music attribution (CC-BY).
- `MAC-SESSION-NOTES.md` — the earlier three-platform port record.
- `shots/` — screenshots per milestone (`aware-constellation.png` is the sky).
