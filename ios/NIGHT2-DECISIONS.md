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
