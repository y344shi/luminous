# Overnight Tick Playbook — 3-direction mode

A 5-minute heartbeat explores **three creative directions in parallel**, each on
its own branch (see `docs/overnight-plan.md`). One narrow, green, committed,
pushed improvement per tick. Never leave the tree red or dirty.

Directions (rotated by tick count):
| idx | direction | foundation branch | luminous branch |
| --- | --- | --- | --- |
| 0 | Liquid Glass | `luminous-glass` | `glass` |
| 1 | Living World | `luminous-sense` | `sense` |
| 2 | Calm Ritual | `luminous-craft` | `craft` |

## Lock (no overlap)
Lock file `scratchpad/tick.lock`. If it exists and is < 12 min old → output
"tick skipped (locked)" and STOP. Else write the time into it; ALWAYS `rm -f` it
at the end.

## The cycle
0. `export PATH="$HOME/.local/bin:$PATH"`. Repo root: `/home/yuxua/foundation`.
1. **Pick direction**: read `scratchpad/tick-count` (default 0); `idx = count % 3`;
   direction + branches from the table. Write `count+1` back.
2. **Clean checkout**: in the repo root, if the tree is dirty from a failed tick,
   `git -C /home/yuxua/foundation checkout -- dreams/seize_the_day` and
   `git -C /home/yuxua/foundation clean -fd dreams/seize_the_day` (node_modules/.next
   are gitignored, safe). Then `git checkout <foundation-branch>`.
3. **Pick item**: the next unchecked `[ ]` for this direction in
   `docs/overnight-plan.md`. Implement it incrementally. Use **Agent subagents**
   for independent sub-parts (in one message), and the **frontend-design skill**
   for visual work. Obey `CLAUDE.md` product + committed-history rules.
4. **Verify**: `cd dreams/seize_the_day && npm run typecheck && npm test && npm run build`.
   If it can't go green, **revert** (`git checkout -- .`) and pick a smaller step.
5. **Document**: check off the item; append a short note to `docs/iteration-log.md`.
6. **Timeline**: `node dreams/seize_the_day/scripts/gen-timeline.mjs`.
7. **Commit** on the foundation branch: `git -C /home/yuxua/foundation add dreams/seize_the_day`
   then commit `"<dir> N: <short>"` + the Co-Authored-By trailer.
8. **Screenshot**: `bash dreams/seize_the_day/scripts/shoot-home.sh <dir>` →
   `docs/shots/<dir>.png`; if it changed, `git add` + amend/commit it.
9. **Push**: `git -C /home/yuxua/foundation subtree push --prefix=dreams/seize_the_day luminous <luminous-branch>`.
   Non-fast-forward? skip the push this tick and log it; continue.
10. **Release lock**: `rm -f scratchpad/tick.lock`.

## Guardrails
- One improvement per tick, on the current direction's branch only.
- Green build + core loop (Add→Now→Complete→Trace) are non-negotiable.
- Committed history is required (CLAUDE.md). Revert rather than leave red/dirty.
- If a direction's list is exhausted, do a 5-lens self-review for that direction
  and add fresh items. If 3 consecutive ticks find nothing safe, idle quietly.
