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
