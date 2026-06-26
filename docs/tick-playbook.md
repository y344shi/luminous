# Overnight Tick Playbook

Each 5-minute cron tick runs ONE narrow build cycle. Keep the core loop alive at
every step. Be incremental — never rewrite the app.

## Lock (prevent overlapping ticks)
Lock file: `scratchpad/tick.lock` (in the session scratchpad dir).
1. If `tick.lock` exists AND its mtime is < 12 minutes old → a cycle is likely
   still mid-flight. Log "tick skipped (locked)" and STOP this tick.
2. Otherwise write the current time into `tick.lock`, do the cycle, and `rm -f
   tick.lock` at the very end (success or failure).

## The cycle
1. **Orient.** Read `docs/next-steps.md` (top unchecked item in the highest
   section) and the tail of `docs/iteration-log.md`. Pick exactly ONE item.
2. **Implement.** Make the change. For independent sub-parts (e.g. a component +
   its test, or several themes), launch 2–3 `Agent` subagents IN ONE message and
   wait for them in the same turn, then integrate. Prefer the synchronous `Agent`
   tool over background work so ticks stay sequential. Reuse `lib/copy.ts`; obey
   the hard rules in `CLAUDE.md`.
3. **Verify.** `npm run typecheck && npm test && npm run build`. Fix any breakage
   before continuing. If you cannot make it green, revert the change (`git
   checkout -- <files>`) rather than leave the loop broken.
4. **Document.** Append a `## Cycle N` block to `docs/iteration-log.md`, refresh
   `docs/test-report.md`, add to `docs/design-decisions.md` if a decision was
   made, and check off the item in `docs/next-steps.md`.
5. **Commit.** `git add dreams/seize_the_day && git commit` on branch
   `seize-the-day/overnight-build` with a `Cycle N: …` subject (+ the standard
   Co-Authored-By trailer). Never commit `node_modules`/`.next`.
6. **Push to luminous.** From the repo root, mirror the app to its own GitHub repo:
   `git -C /home/yuxua/foundation subtree push --prefix=dreams/seize_the_day luminous main`
   (remote `luminous` = git@github.com:y344shi/luminous.git, SSH key works). If it
   rejects on a non-fast-forward, that's fine to skip a tick — log it, continue.
7. **Release lock.** `rm -f scratchpad/tick.lock`.

## Stop conditions
- If `docs/next-steps.md` has no unchecked items left, do a self-review cycle:
  write/extend `docs/morning-review.md` through the five lenses (product designer,
  ISFP user, tired 3AM user, technical maintainer, future iOS dev), then add fresh
  items to `next-steps.md` from what you find.
- If three consecutive ticks find nothing safe to do, idle quietly.

## Guardrails
- One improvement per tick. Small > grand.
- The core loop (Add→Now→Complete→Trace) and a green build are non-negotiable.
- When unsure, choose the simpler, softer option (per the master brief §35).
