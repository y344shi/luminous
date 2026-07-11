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
