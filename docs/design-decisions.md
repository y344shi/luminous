# Design Decisions — 《今天别消失》

Product/engineering decisions, with reasons and tradeoffs. Append as we go.

---

### D1: Build the full core loop in Cycle 1, not just Home
- **Reason:** The brief's success criterion is emotional truth of the loop (wish → opportunity → trace), not feature count. A half loop has no feeling to react to.
- **Alternatives:** Strict cycle-by-cycle (Home only first).
- **Tradeoff:** More surface to keep working at once, but the app is immediately judgeable as a product.

### D2: Zustand store + manual hydrate, not `persist` middleware
- **Reason:** Full control over SSR (no localStorage on server) and first-run mock-garden seeding without hydration mismatch.
- **Tradeoff:** A little boilerplate; components must guard on `hydrated` to avoid SSR/client divergence.

### D3: Themes via `[data-theme]` + CSS variables, switched on `<html>`
- **Reason:** Runtime theme switching with zero JS style recomputation; "themes change feeling, not layout" stays literally true (same components, different vars). Tailwind v4 `@theme inline` maps the vars to utility colors.
- **Alternatives:** Per-theme Tailwind config / JS-injected styles.
- **Tradeoff:** Components reference `var(--x)` via arbitrary values rather than named semantic utilities everywhere.

### D4: Late-night safety is a hard gate, not just a score penalty
- **Reason:** Safety. At late_night, `rankSeeds` *drops* unsafe seeds (outdoor/downtown/exploration/high-energy/>20min) entirely; it never relies on a rescue seed merely out-scoring them.
- **Tradeoff:** If a user has only "big" wishes, late night may show few options — acceptable; the rescue/stop-loss framing fills that.

### D5: `triggerConditions` give an additive scoring bonus
- **Reason:** Intent-tagged seeds ("avoidant_mood", "rescue_mode", "lonely") should rise exactly when the moment calls for them. Pure category/mood affinity wasn't enough (a tiny "learning" wish was out-ranking the intended "creation" one for avoidant mood).
- **Tradeoff:** Another knob to balance; kept additive and capped so it nudges rather than dominates.

### D6: Mock parser is rule/keyword based and isolated behind one function
- **Reason:** No API key, no network, fully testable, instant. `parseSeedMock` and `draftToSeed` are the seam; a real-AI parser can swap in behind the same `SeedDraft` shape.
- **Tradeoff:** Limited to known wish shapes; unknown text falls back to a gentle generic recovery seed.

### D7: Partial completion always produces a positive trace; skipped does not "disappear"
- **Reason:** Core philosophy — "做一点也算", never shame. Skipped returns a gentle "愿望还在" message and is not stored as a trace by default.
- **Tradeoff:** Trace journal under-counts effort that was skipped — intentional.

### D8: First run plants a mock garden
- **Reason:** An empty garden feels dead for an ISFP user evaluating feel. Seeds disappear the moment the user adds/edits their own.
- **Tradeoff:** Slight "where did these come from" — mitigated by soft copy and Settings reset.

### D9: `transit` added to `SemanticTime`
- **Reason:** The brief's mock data uses it as a preferred-time window for tiny actions, though the type omitted it. Treated as a soft "on the move" context.

### D11: The bare word 任务 is allowed; todo *framing* is what's forbidden
- **Reason:** The garden subtitle "这些不是任务" is core copy — it names the thing the app refuses to be. Banning the substring 任务 would forbid the very sentence that expresses the philosophy.
- **What's forbidden instead:** todo mechanics/framing (待办, 任务列表, 完成任务, todo, deadline, overdue, 优先级, 完成率, streak, 打卡) and shaming (失败, you must/failed).
- **Tradeoff:** A curated, non-exhaustive list — must grow as copy grows. Enforced by the Cycle-8 copy-lint test over both the `copy` dict and rendered screens.

### D10: PWA via Next metadata `manifest.ts` + a hand-written `sw.js`, no PWA plugin
- **Reason:** Zero new runtime deps; full control over the (deliberately tiny, fail-soft) caching strategy. Service worker registers in production only, so it can never interfere with dev/HMR.
- **Alternatives:** `next-pwa`/Serwist.
- **Tradeoff:** We maintain the SW by hand, but it's ~40 lines and easy to reason about. Offline is treated strictly as an enhancement — registration failures are swallowed.
- **Icons:** generated at build-time-once with `sharp` (already present transitively) from an inline SVG, kept in the warm-paper palette with content inside the maskable safe zone.
