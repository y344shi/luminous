# Night 2 — organize · link · make apparent (2026-07-10)

A second overnight session. Goal: make the system **more organized, linked, and
apparent**, update the **calendar**, and overhaul **notes** into a click-through
**card** system with **Apple Pencil** support. Same discipline as Night 1:
worktree `wt-aware` on `ios-aware`, one narrow green phase per cycle, commit +
push trio (`ios-aware` → `ios-glass` + `macos`), decisions logged.

## ⚠️ READ FIRST — why "the modes don't switch" (it's not a bug)
The skin split (glass / ocean / paper) is **built, correct, and reactive** on
`ios-aware` (= `origin/ios-glass`). The running **live Xcode copy**
(`net/luminous`) is on a LOCAL `ios-glass` that is **42 commits behind** and
**predates W5** — its `HomeView` has no `skin == .ocean` branch at all, so its
skin picker only swaps the background. Nothing tonight will be visible until the
running build is up to date. **To see the work:** close Xcode on the live copy,
then open the up-to-date worktree instead —
`/Users/y344shi/Desktop/luminous/wt-aware/ios/Luminous.xcodeproj` (clean, on
`ios-aware`, has everything). (Alternative: close Xcode, fast-forward local
`ios-glass` to `origin/ios-glass`, reopen — but the live copy has uncommitted
edits, so the worktree route is safer.)

## Phases (sequenced)

- **P1 · Make skins apparent from Home.** A small, always-visible skin control on
  Home (cycles 玻璃 / 海面 / 纸页, or a 3-dot segmented tap) so switching is
  immediate and obvious — not buried in Settings. Directly answers the complaint.
- **P2 · Notes → click-through card deck.** Redesign the 手帐 notes list
  (`PursuitPage.notesList`) into a card system: each note is a card you page
  through (swipe / tap), with an "add" card. Calm, legible, no productivity feel.
- **P3 · Apple Pencil notes.** New `PursuitNote.Kind = .sketch` holding PencilKit
  drawing data; a PencilKit canvas card to draw a handwritten note; sketch cards
  render inline. iPad/Pencil-first, degrades on iPhone/Mac. Persisted like notes.
- **P4 · Calendar update.** Improve `WishCalendarView` + make it apparent/linked
  (reachable from Home, not only Settings); polish per the calendar-stack spec.
- **P5 · Organize & link.** A small hub that links calendar · notes · 今天的小机器
  · 痕迹 so the system reads as one connected thing. Cross-links where natural.
- **Morning wrap.** Summary in `NIGHT2-DECISIONS.md`; stop the loop.

## Rails (unchanged from Night 1)
- Never touch the live Xcode copy (`net/luminous`) or swap branches under it.
- Green gate every cycle: `cd ios && swift test` AND iOS `xcodebuild`; macOS at
  milestones. Revert rather than leave red. Count-free, no productivity framing.
- PencilKit is iPad/Pencil-centric — degrade cleanly where unavailable; verify on
  device. Every LLM-touching change keeps the `@Generable` + fallback + forbidden
  words pattern.
