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
