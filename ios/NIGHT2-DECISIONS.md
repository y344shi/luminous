# Night 2 — decision log (2026-07-10)

Proceeding on best judgement per the user's standing overnight mandate;
decisions recorded here for morning review.

**N0 · The "modes don't switch" report is a sync issue, not a bug.** Verified:
the live Xcode copy (`net/luminous`) runs a local `ios-glass` 42 commits behind
`origin/ios-glass`; `git show ios-glass:HomeView.swift | grep -c 'skin==.ocean'`
= 0 — that build predates the entire W5 skin split, so its picker only swaps the
backdrop. The W5 code on `ios-aware` is correct and reactive (`AppStore` is
`@Observable`; `setAesthetic` → `aesthetic` → `HomeView.skin` via
`effectiveAesthetic`). RESOLUTION for the user (they must run an up-to-date
build): close Xcode on the live copy and open the `wt-aware` worktree project
(clean, has everything) — logged in NIGHT2-PLAN.md. I cannot fix their local git
(hard rule: never touch the live copy while Xcode is open). Tonight I ALSO add a
Home-level skin switcher (P1) so the modes are apparent once they're on a current
build.

**N1 · P1 shipped — skins apparent from Home (aware 44).** Added a small
always-visible skin switcher to HomeView.topOverlay: a material capsule of the
three skin SF Symbols (circle.hexagongrid / water.waves / doc.text), active one
filled with accentSoft, tap → store.setAesthetic with a 0.35s crossfade. Shown
on every skin. No new state (reads `skin`, writes via the existing seam). This
answers "the three-mode switching isn't apparent" — now it's one tap on Home.
83 tests + iOS green. Next: P2 (notes → click-through card deck).

**N2 · P2 shipped — notes as a click-through card deck (aware 45).** Replaced
PursuitPage.notesList + addRow with `notesDeck`: on iOS a paged TabView
(.tabViewStyle(.page)) of note cards + a trailing add card; each card shows the
kind glyph (leaf/lightbulb/sparkles), the text in a 17pt legible face, the
friendly date, and a 40pt delete target. macOS has no .page style → degrades to a
horizontal ScrollView deck of the same 300pt-wide cards (#if os). DECISION: no
selection binding on the TabView (lets it manage its own index) — avoids stale
tag/out-of-range bugs when a note is deleted, at the cost of not auto-jumping to a
freshly added note (acceptable; the add card is always last). The empty state is
just the add card itself (invites the first thought), so dropped the old
empty-text line. Count-free, calm. 83 tests + iOS green. Next: P3 (Apple Pencil
sketch notes into the same deck).

**N3 · P3 shipped — Apple Pencil handwritten notes (aware 46).** Sketch notes
slot into the same deck. DECISION (storage): new PursuitNote.Kind = .sketch keeps
its PKDrawing as base64 in the note's `text` field — zero Persistence @Model
change, loss-free, and it flows through the existing addNote/removeNote/loadNotes
path untouched (mirrors D18). Only noteGlyph needed the new case; no other
exhaustive switch on Kind exists. DECISION (platform): all PencilKit code lives in
PencilNote.swift behind `#if canImport(PencilKit) && os(iOS)` — SketchCanvas
(PKCanvasView + PKToolPicker, drawingPolicy .anyInput so finger works without a
Pencil) and SketchComposerSheet (compose → base64 on 记下). PursuitPage gates the
画一张 button and the .sheet the same way; SketchNote.image(from:) returns nil
off-iOS so a sketch note renders a 一张手写的便签 placeholder rather than crashing.
Verified the macOS build stays green with the degrade. Tool-picker setup guarded
on !isFirstResponder to avoid update loops. Pencil is iPad-centric → handwriting
itself needs on-device verification (Simulator compiles + won't crash). 83 tests +
iOS + macOS green. Next: P4 (calendar update + make it reachable/linked from Home).

**N4 · P4 shipped — calendar apparent + today highlighted (aware 47).** DECISION
(reach): WishCalendarView is already a self-contained modal (own NavigationStack +
完成 dismiss), so rather than convert it to a pushed Route I surfaced it from Home
the same way Settings does — a calendar button in the bottomOverlay HStack →
.sheet(isPresented: $showCalendar) { WishCalendarView() } (macOS gets a sized
frame). Lowest-risk, mirrors the existing presentation exactly, and now it's one
tap from Home instead of buried in Settings. POLISH: added WishCalendar.todayIndex
and DayStackColumn.isToday — today's weekday column reads in accentText with a
small 今天 pill. Left the rest of the calendar-stack (pile split, heaviness, card
→ sheet, 不是日程 footnote) untouched (already good; a bigger refactor would risk
the gate). Count-free, no schedule/overdue language. 83 tests + iOS green. Next:
P5 (organize & link — a hub tying calendar · notes · 今天的小机器 · 痕迹 together;
LAST Night-2 phase, then morning summary + stop).

**N5 · P5 shipped — 去处 hub, Night 2 COMPLETE (aware 48).** New LinkHubView: a
calm sheet of four soft cards (愿望日历 · 手帐/想法 · 今天的小机器 · 痕迹), each
icon + name + one-line feeling, tap → that surface. DECISION (declutter): folded
the two newest scattered Home buttons (小机器 cube + 日历) into ONE
square.grid.2x2 hub entry; translate + add stay as Home quick-access. DECISION
(routing): reused existing reach rather than new plumbing — machine =
path.append(Route.buildToday); 痕迹 & 手帐 = AppRouter tab switch (.traces /
.seeds, since notes are per-pursuit and live under 愿望); calendar = its existing
sheet, opened via a 0.35s asyncAfter once the hub sheet dismisses (two sheets
can't share an anchor simultaneously). HomeView gained @Environment(AppRouter).
Count-free, skin-aware. 83 tests + iOS + macOS green.

---

## ☀️ Morning summary — Night 2 (2026-07-10), P1→P5 all shipped

Good morning. Night 2 is complete — five green phases (aware 44→48), all pushed
to `ios-aware` → `ios-glass` + `macos`. The live Xcode copy was never touched.

### ⚠️ FIRST — you must run an up-to-date build to see ANY of this
The "modes don't switch" report was the tell: your live Xcode copy
(`net/luminous`) was 42+ commits behind and predated the whole skin split, so it
only ever showed the planetarium. **Close Xcode on the live copy and open the
worktree project instead** —
`/Users/y344shi/Desktop/luminous/wt-aware/ios/Luminous.xcodeproj` (clean, on
`ios-aware`, has everything). Or, with Xcode closed and a clean tree,
fast-forward local `ios-glass` to `origin/ios-glass`. Until then none of Night 1
(skins, day-object) or Night 2 is in your build.

### What shipped (P1→P5)
- **P1 · Skins apparent (aware 44):** an always-visible skin switcher in the Home
  top bar — tap 玻璃/海面/纸页, immediate crossfade. Answers the complaint.
- **P2 · Notes as a card deck (aware 45):** the 手帐 notes are a click-through
  paged deck (add card at the end); macOS degrades to a horizontal deck.
- **P3 · Apple Pencil notes (aware 46):** a `.sketch` note kind holding a base64
  PKDrawing; a 画一张 canvas card (finger or Pencil); sketch cards render inline;
  degrades cleanly off-iOS.
- **P4 · Calendar apparent (aware 47):** 愿望日历 reachable from Home; today's
  column highlighted with a 今天 pill.
- **P5 · 去处 hub (aware 48):** one hub links calendar · 手帐 · 小机器 · 痕迹; the
  scattered Home buttons fold into it.

### Verify ON DEVICE (after syncing the build)
1. The Home **skin switcher** genuinely swaps glass ↔ ocean ↔ paper (the ocean
   sloshes with the gyro; paper is the note-card list).
2. **Apple Pencil** handwriting on an iPad (画一张 → draw → 记下 → the sketch card
   shows your drawing). Finger works too; Pencil is the real test.
3. The **notes card deck** paging, the **calendar** from Home, and the **去处** hub
   routing (each card lands on its surface).

### Best next steps
- **Per-skin craft hulls** for 今天的小机器 (glass sky-craft / ocean raft / paper
  folded toy) — the CP-F piece deferred on Night 1.
- **Notes polish:** let a sketch note be reopened/edited in the canvas; pinch-zoom
  a sketch card; optional per-note color.
- **Paid Apple Developer Program:** CloudKit sync (schema ready), HealthKit,
  TestFlight — so the calendar/notes/machine sync across your devices.
- **Hub as home:** consider making 去处 a light home for the paper skin too.

Loop stopping now — no more scheduled wakes. Rest well; it's all committed,
green, and pushed.
