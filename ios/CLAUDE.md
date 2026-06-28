# iOS port — working rules

The native SwiftUI port of 《今天别消失》. Product logic mirrors the web `lib/`
(see `../CLAUDE.md`). Xcode 16 synchronized file groups: new `.swift` files added
under `Luminous/` auto-join the target.

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

## Build / verify
Use the `BuildProject` MCP tool (xcode-tools), not the command line. `XcodeRefreshCodeIssuesInFile`
for fast per-file diagnostics.
