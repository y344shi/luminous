# iOS port — working rules

The native SwiftUI app (iOS / iPadOS / macOS / watchOS) of 《今天别消失》.
**New / no context? Read [`ARCHITECTURE.md`](ARCHITECTURE.md) first** — the full
onboarding brain (goals, ideals, stack, data structures, scoring spine,
persistence, branch topology). Then `README.md` for the feature tour. Product
logic mirrors the web core (see `../CLAUDE.md`).

Xcode synchronized file groups: new `.swift` files under `Luminous/` auto-join the
app target — but NOT the watch target (explicit FACE-UUID refs in
project.pbxproj) and NOT the test package (`Package.swift` `sources:` list). If a
watch-shared file (Store/Scoring/Domain…) gains a new type dependency, add that
file to the watch target's pbxproj refs, or the watch build breaks silently.

## Branches (as of the 2026-07 consolidation): exactly two
- **`main`** — the canonical trunk (web + iOS). Checked out in the `wt-aware/`
  worktree (the non-live build area) and on the remote. **Do agent work here.**
- **`ios-glass`** — the branch the **live Xcode copy** (`net/luminous`) tracks.
  Kept in lockstep with `main`.
- Retired in the consolidation: `ios-aware` (the old integration-branch name),
  `macos`, and the stale direction branches. `stashed_history` (local) archives
  pre-consolidation edits.
- Mirror after landing on the trunk: `git push origin main` then
  `git push origin main:ios-glass` (keep the two equal).

## ⛔️ NEVER switch git branches while Xcode has this project open
`git checkout` / `git switch` / `merge` / `rebase` / `cherry-pick` / `stash` that
rewrites files here **corrupts Xcode's open project + index and has broken the
workstation.** Rules:
- Stay on the branch the user has open; make **additive commits** only.
- Multi-branch direction work (`glass` / `sense` / `craft`) → use a **separate
  `git worktree`** per branch (`git worktree add ../luminous-<dir> <branch>`), open
  only one in Xcode at a time. Never swap branches under the live project.
- Before any unavoidable branch-changing git op: **stop, ask the user to close
  Xcode**, confirm a clean tree, then proceed.
- Read-only git (`status` / `log` / `branch` / `diff` / `ls-files`) is always fine.

## Build / verify (the green gate — every change)
1. `cd ios && swift test` — the pure-core SwiftPM harness (fast; pins the
   late-night gate and all safety rules). New pure files need one line in
   `Package.swift` `sources:`.
2. `xcodebuild -scheme Luminous -sdk iphonesimulator -destination
   'platform=iOS Simulator,name=iPhone 17 Pro' build`
3. At milestones also: `-destination 'platform=macOS'` and
   `xcodebuild -scheme "Luminous Watch App" -sdk watchsimulator build`.

When the xcode-tools MCP server is connected, `BuildProject` /
`XcodeRefreshCodeIssuesInFile` are fine alternatives for builds/diagnostics.

## House rules for intelligence
- The linear scorer is the spine; every new signal is ONE clamped additive term.
- Hard gates (late-night) live in code, never prompts.
- Every LLM feature: `@Generable` structured output + deterministic fallback +
  `ForbiddenWords.passes` on anything shown (the `LearningMerge` pattern).
- FoundationModels is unavailable in the Simulator — LLM paths degrade there by
  design; verify them on a device.

## 📖 Reading & Study Suite (2026-07) — read the note first
The 扫书 → 逐字读 → 批注 → 分享 arc (scan a picture book, read it word-by-word with
on-device translation/notes/Siri TTS, annotate with Apple Pencil, AirDrop the
annotated `.luminousbook`) is documented in **[`READING-SUITE-NOTES.md`](READING-SUITE-NOTES.md)**
(progress + ideology + build/install gotchas) and **[`WORD-STUDY-PLAN.md`](WORD-STUDY-PLAN.md)**
(design + queue). Next queued: register the `.luminousbook` UTI so AirDrop opens
the app on tap (needs an Info.plist doc-type edit — **Xcode must be closed**).

## ▶️ Next up — the TODO backlog (a fresh clone can start here)

Onboarding: read `ARCHITECTURE.md`, then work in `wt-aware/` on `main` (never
rewrite the live copy while Xcode is open). For EVERY item: keep the scorer the
spine (one clamped term per signal), safety in code, each LLM feature
`@Generable` + fallback + `ForbiddenWords`; run the green gate (`swift test` +
iOS build; macOS at milestones); commit small (single-quoted `-m`, Co-Authored-By
trailer); then mirror `git push origin main` + `git push origin main:ios-glass`.
Mark an item done here in the same commit.

### Ready to implement now (no external blockers)
1. **Per-skin craft hulls for 今天的小机器** — glass sky-craft / ocean raft / paper
   folded toy. Add a per-skin base geometry in `DayCraftArt.swift`; pass the skin
   into `DayObjectStage` + `DayObjectSnapshot` (both share `DayCraftArt`). Keep it
   calm, Reduce-Motion still. (The CP-F piece deferred on Night 1.)
2. **Sketch-note editing** — reopen a `.sketch` note in the PencilKit canvas and
   re-save; pinch-zoom a sketch card. Files: `PencilNote.swift`, `PursuitPage.swift`
   (iOS-gated, degrade off-iOS).
3. **Persist the moon map** — planetarium moon attachments are transient
   (`HomeView.moonOf` `@State`). Persist per-profile via `Persistence` (a small
   payload record or an `EventRecord` kind), rehydrate on load.
4. **Distinct app icons** — `AppIcon-1024` / `-dark-1024` / `-tinted-1024` are
   currently the SAME image. Replace with real light/dark/tinted art in
   `Assets.xcassets/AppIcon.appiconset/` (Contents.json already wires the slots).
5. **Per-word spaced repetition** — extend the existing `ReviewQuiz`
   (`ExecutorViews.swift`) with per-word `nextReview` scheduling on `learnedVocab`
   (surface 1 due review + 2 new); persist the dates. Keep it a gentle offer.
6. **去处 hub as the paper skin's home** — consider surfacing `LinkHubView` as
   paper's Home entry so the calm skin leads with the connected map.

### Blocked — needs the paid Apple Developer Program ($99/yr)
7. **CloudKit sync** — the SwiftData schema is already sync-shaped; wiring is
   entitlement-gated (`Persistence.cloudActive`, `tdd.cloudSync`). Add the iCloud
   container + entitlement, then verify cross-device.
8. **HealthKit arousal** — the `Arousal` signal is stubbed (`Sensors.swift`). Wire
   HealthKit heart-rate → `.calm`/`.elevated` → the existing clamped `sensorBonus`
   term. Also un-stub mic loudness → `Ambient`.
9. **Watch App Group sync** — the watch is UserDefaults-only; share seeds/traces
   iPhone↔watch via an App Group + WatchConnectivity.
10. **TestFlight** distribution.

### Verify on a physical device before shipping (not code, but required)
- FoundationModels LLM paths (parser, plans, `SituationCare`, `WeekReview`) — the
  Simulator always falls back.
- Apple Pencil handwriting on an iPad; SceneKit Play scene + PNG snapshot; skins
  actually swapping; late-night sensing out in the real world.

See `VISION-AUDIT.md` for the deeper product/architecture audit.
