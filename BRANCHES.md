# Branch guide — what each branch means, where its tip is, and the timeline

*The repo's map. Update the tip table whenever the picture changes; deeper
context lives in [`docs/CONTEXT.md`](docs/CONTEXT.md).*

## The one-paragraph story

`main` is the **web trunk** (Next.js), fed by the WSL machine via
`git subtree push`. On 2026-06-28 the native SwiftUI app was born **on top of
main** and has been sprinting since — so the three native branches are a clean
**descendant** of main (merge-base = main's tip), not a fork. Native work is
done in git **worktrees** (one folder per branch — the hard rule: never switch
branches under the open Xcode project), and after every green change the three
native branches are **fast-forwarded together** so they always share one tip.

## Branches and where their tips are

| branch | role | tip (2026-07-04) | checked out at |
| --- | --- | --- | --- |
| `main` | **web trunk** — Next.js app + `@luminous/core`; WSL subtree-pushes here | `b23574e` *core 43* (2026-06-29) | WSL: `~/foundation/dreams/seize_the_day` |
| `ios-glass` | **native trunk** — the canonical branch for the iOS/macOS/watchOS app | `c02dfc0` *aware 17: 手帐* | Mac live Xcode copy: `net/luminous` (pull with Xcode **closed**) |
| `ios-aware` | native **working branch** — new commits land here first | `c02dfc0` (same) | Mac worktree: `wt-aware` |
| `macos` | native mirror (historical name from the three-platform port) | `c02dfc0` (same) | Mac worktree: `wt-macos` (stale checkout @ `717995c`) |
| `ios-sense` / `ios-craft` | retired design directions, local-only | `994da4c` / `3656884` | Mac worktrees: `wt-sense` / `wt-craft` (archive) |

**Invariant:** `ios-aware == ios-glass == macos` on the remote at all times —
push new work to `ios-aware`, then `git push origin ios-aware:ios-glass
ios-aware:macos`. If they ever differ, `ios-glass` wins (it's the trunk).

**main vs native:** native contains *all* of main up to `b23574e` (the web app
compiles from any native branch). main does **not** contain the ~120 native
commits. Do not merge native → main wholesale: main stays the web trunk.

> ⚠️ **WSL note:** `main` now carries doc commits made directly on GitHub-side
> (this file). Before the next `git subtree push`, run
> `git subtree pull --prefix=dreams/seize_the_day luminous main` (or merge)
> so the subtree histories stay reconciled.

## Project timeline

| date (2026) | milestone | commits |
| --- | --- | --- |
| ≤ 06-28 | **Web sprint** (`core 1–43`, WSL overnight loop): sensor fusion, illustration packs, three skins, `@luminous/core` extraction | main history |
| 06-28 | **Native born**: iOS + macOS + watchOS from one Xcode project, runtime-switchable skins | `420459a` |
| 06-29 | iOS sensor-fusion port (motion/location→weather); **planetarium glass home** (orbits, tilt-gravity, drag-to-reveal); web trunk pauses at *core 43* | `2330b98` `8ab166d` `b23574e` |
| 06-30 | Physically-rendered **black hole** + shooting stars; **real gravity-sim orbits** (velocity-Verlet); **photo translate** (OCR→EN+中文); learning-as-anchor (history + LLM merge) | `a75e0bd` `3d86e44` `dc0a937` `0c56457` |
| 07-02 | **Vision audit**, then the **"aware" overnight build** (C0–C12): SwiftPM test harness · SwiftData multi-garden DB · life-event log + rhythm · on-device **LLM seed parser** · learned home/work · nearby **scout** · recurrence + fit-learning · mentality estimate · per-category executors · default-OFF notifications · reason-writer · weekly review | `717995c`, `767f70a…85ccf27` |
| 07-03 | Orbit tilt-physics fix (self-learned rest pose); **task breakdown + live resources** (routes/vocab/photo/breath); **记忆星座** — every trace a permanent star + birth ceremony | `9303efe` `9a1c50e` `2f6bc96` |
| 07-04 | Place **kind-diversity** (parks/attractions/nature) + **recipe deep-assist** (dish→ingredients→nearest market); illustrated docs (`ios/README.md`, `ios/TOUR.md`); **手帐** pursuit journal pages + growth suggestions | `9239ff8` `977819f` `e179272` `c02dfc0` |

Full per-commit history: `git log --oneline ios-glass` · illustrated feature
map: [`ios/TOUR.md`](ios/TOUR.md) · session records: `ios/OVERNIGHT-SESSION.md`,
`ios/MAC-SESSION-NOTES.md`.

## Working rules (short form)

- **Never** run branch-changing git ops in a folder Xcode has open — use a
  worktree per branch (`git worktree add ../wt-<name> <branch>`).
- Every change lands as a **green committed step** (native gate:
  `cd ios && swift test` + `xcodebuild`; web gate: `typecheck && test && build`)
  and is pushed the same cycle.
- New native work: branch from `ios-glass`, work in a fresh worktree, keep the
  trio fast-forwarded when it merges.
