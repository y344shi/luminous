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
