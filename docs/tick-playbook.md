# Overnight Tick Playbook — skins-on-main mode

A 5-minute heartbeat that improves **luminous** on a single trunk (`main`).
We no longer rotate direction branches. The foundational core is shared in
`lib/`, and each look (glass / ocean / paper / …) is a swappable **skin**
component selected by config (`docs/architecture-skins.md`). Each tick makes
**one narrow, green, committed, pushed improvement** — to a skin *or* to the
shared core — and never leaves the tree red or dirty.

## What a tick may touch
- A single **skin** under `components/home/skins/` (visual polish, physics, a new
  skin), or
- The **shared core** under `lib/` / shared home pieces / `app/` shell (a feature
  every skin inherits — scoring, context, traces, nav, etc.).

Pick from `docs/next-steps.md` (the running backlog). One item per tick.

## Lock (no overlap)
Lock file `scratchpad/tick.lock`. If it exists and is **< 12 min old** → output
`tick skipped (locked)` and STOP. Otherwise write the current time into it, and
**ALWAYS `rm -f scratchpad/tick.lock` at the end** (success, revert, or bail).

## The cycle
0. `export PATH="$HOME/.local/bin:$PATH"`. Repo root: `/home/yuxua/foundation`.
   App: `dreams/seize_the_day`.
1. **Acquire the lock** (above). Bail if locked & fresh.
2. **Clean checkout** on `main`. If a prior tick left the tree dirty:
   `git -C /home/yuxua/foundation checkout -- dreams/seize_the_day` and
   `git -C /home/yuxua/foundation clean -fd dreams/seize_the_day`
   (`node_modules` / `.next` are gitignored, safe). Then `git checkout main`.
3. **Pick one item** — the next unchecked `[ ]` in `docs/next-steps.md`. Prefer
   small. Use **Agent subagents** for independent sub-parts (in one message) and
   the **frontend-design skill** for visual work. Obey `CLAUDE.md` product rules
   (no shame / tasks / streaks; late-night safety gate; tender voice).
   - Skin work → edit only that skin + its own assets; don't fork core logic into
     a skin. If two skins need the same thing, it belongs in `lib/` or the shared
     home pieces.
   - Core work → keep it skin-agnostic; verify it under at least the active skin.
4. **Verify (green gate)**:
   `cd dreams/seize_the_day && npm run typecheck && npm test && npm run build`.
   All three must pass. If it can't go green, **revert** (`git checkout -- .`)
   and pick a smaller step — never commit red.
5. **Document**: check off the item in `docs/next-steps.md`; append a one-line
   note to `docs/iteration-log.md` (what changed, which skin/core).
6. **Timeline**: `npm run timeline` → regenerates `docs/TIMELINE.md`. Stage it.
7. **Commit** on `main` (committed history is a rule — `CLAUDE.md`):
   `git -C /home/yuxua/foundation add dreams/seize_the_day` then commit with a
   clear subject + the Co-Authored-By trailer. Subjects name the surface, e.g.
   `glass N: …`, `ocean N: …`, `paper N: …`, or `core N: …`.
8. **Screenshot the touched skin(s)** — `scripts/shoot-home.sh <skin>` sets
   `NEXT_PUBLIC_AESTHETIC` from the label:
   ```bash
   bash scripts/shoot-home.sh glass
   bash scripts/shoot-home.sh ocean
   bash scripts/shoot-home.sh paper
   ```
   → `docs/shots/<skin>.png`. For a core change that affects every look, reshoot
   each skin; for a skin change, just that one. If a shot changed, `git add` it
   and amend/commit.
9. **Push**: from the repo root,
   `git -C /home/yuxua/foundation subtree push --prefix=dreams/seize_the_day luminous main`.
   Non-fast-forward? Skip the push this tick, log it, continue.
10. **Release the lock**: `rm -f scratchpad/tick.lock`.

## Guardrails
- One narrow improvement per tick, on `main` only. Small > grand. Never rewrite
  wholesale.
- Green build + the core loop (Add → Now → Complete/Partial → Trace) are
  non-negotiable.
- Keep core skin-agnostic and skins thin. A skin renders the field; it does not
  own domain logic.
- Committed history is required. Revert rather than leave the tree red or dirty.
- If `docs/next-steps.md` is exhausted, do a short self-review (one per skin + one
  for the shared core) and add fresh items. If three consecutive ticks find
  nothing safe to do, idle quietly.
