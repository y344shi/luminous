# Morning Review — 《今天别消失》

A self-review after Cycles 1–17. The app meets the brief's "Definition of Done
for Tonight" (§34): core loop works, wishes persist, Now recommends, completion
+ partial generate traces, late-night mode protects, 5 themes, scoring/parser/
trace tests, docs maintained. State at review: 116 tests (14 files), 10 routes,
typecheck clean, build green, full WCAG-AA text contrast across all themes.

Reviewed through five lenses. Findings are concrete and tied to code.

---

## 1. Product designer
**Strengths**
- The loop has emotional truth: wish → "现在别消失" → one small action → "今天没有消失，因为……". Partial counts; skipped doesn't shame.
- Late-night safety is a real, tested hard gate, not a slogan.
- Tone is guarded by a test (copy-lint), so it can't drift.

**Issues**
- **Only one opportunity is shown at a time** (`NowFlow` `opps[activeIndex]` + 换一个). The brief frames 1–3 *choices*. One-at-a-time is calmer (ISFP-friendly) but hides that the app considered alternatives. Consider showing the top card with 1–2 muted "或者……" peeks. *(P2)*
- **First-run mock garden is unexplained** (`store.hydrate`). Seven wishes the user didn't write may read as "someone else's data." A one-line "这些是示例，随时可以收起来" or a dismissible note would help. *(P2)*
- **"今天先这样" (onLater)** shows a trace-styled card but saves nothing — gentle, but a returning user might expect it recorded. Acceptable; document the intent in-copy. *(P3)*

## 2. ISFP user (feeling-led, hates being managed)
**Strengths**
- One primary action per screen; big soft cards; warm copy; skippable context.
- Themes change *feeling*; the late-night Soft Ritual offer is a lovely touch.

**Issues**
- **`window.confirm` on data reset** (`SettingsPanel:172`) is a jarring system dialog that breaks the soft aesthetic — the one place the OS intrudes. Replace with an in-app soft confirm sheet. *(P1 — aesthetic consistency)*
- **Trace dates are raw `YYYY-MM-DD`** (`TraceJournal`). "今天 / 昨天 / 6月23日" would feel human, not log-like. *(P2)*
- No gentle first-open orientation of the concept (what is a Seed? why "别消失"?). A single calm intro card could earn trust. *(P3)*

## 3. Tired user at 3 AM
**Strengths**
- Late-night gate removes going-out/high-energy/long actions and surfaces stop-loss; rescue seed ranks first (tested).
- Soft Ritual theme offer dims the screen; reduced-motion respected.

**Issues**
- The late-night **theme offer is only on Home**, not on `/now` where the rescue copy lives — a 3AM user who deep-links to Now misses it. Surface it there too. *(P2)*
- Quiet-hours is computed + shown but **nothing actually suppresses anything** yet (no notifications exist). Fine tonight, but the live indicator could imply more than it does. *(P3, already logged)*

## 4. Technical maintainer
**Strengths**
- `lib/` is pure + React-free (iOS-ready); scoring is rng-injectable; storage validates on load; AI parser isolated behind one seam; 116 tests incl. integration + contrast + a11y + API.
- Docs are genuinely maintained per cycle; decisions recorded (D1–D13).

**Issues**
- **`globals.css` and `themes.ts` duplicate the token values** and must be hand-kept in sync. A test asserts contrast from `themes.ts` but nothing asserts the two sources *match*. Add a guard test (parse `globals.css` `[data-theme]` blocks, compare to `themes.ts`). *(P1 — silent-drift risk)*
- `Opportunity` is transient (never persisted); schema anticipates it. Fine, but note the gap. *(P3)*
- No CI config in-repo; tests/build are run manually each tick. A `.github/workflows` would lock it. *(P2)*

## 5. Future iOS developer
**Strengths**
- Domain logic already framework-free; `ios-roadmap.md` lists the exact `packages/core` / `packages/design` lift.
- PWA (manifest + SW + safe-area + maskable icons) is the right bridge.

**Issues**
- **No actual workspace split yet** — `packages/*` is still planned. The lift is low-risk *mechanically* but high-churn for one autonomous tick; best done deliberately. *(P2)*
- Theme tokens live in CSS + TS; RN can't read CSS. `themeToCssVars`/`themes.ts` is the RN-friendly source — keep it authoritative (ties back to the sync-guard issue above). *(P2)*

---

## Top fixes to schedule (added to next-steps.md)
1. **P1** Replace `window.confirm` reset with an in-app soft confirm.
2. **P1** Token-sync guard test: `globals.css` `[data-theme]` ↔ `themes.ts`.
3. **P2** Human trace dates (今天 / 昨天 / M月D日).
4. **P2** Surface the late-night theme offer on `/now` too.
5. **P2** Associate a `<label>` with the Add textarea (a11y).
6. **P2** Explain / make dismissible the first-run mock garden.

## Verdict
It feels like a life-anchor, not a todo app. The core loop is emotionally true
and technically guarded. The remaining work is polish (aesthetic consistency,
human dates) and platform (workspace split, live DB/AI) — none of it threatens
the soul of the product.

---

# Round 2 — Cycle 28

All Round-1 P1/P2 items shipped (Cycles 19–27): soft confirm, token-sync guard,
human dates, `/now` late-night offer, form labels, first-run garden note,
opportunity peeks, CI, core-purity guard. State: 154 tests (19 files), 10 routes,
typecheck clean, build green. A fresh pass through the five lenses, grounded in
the current code.

## 1. Product designer
- **No first-open orientation.** The concepts (Seed / 锚点 / Trace, why "别消失")
  are never introduced; a new user meets a pre-seeded garden with no framing. One
  calm, dismissible intro card on first run would earn trust. *(P2)*
- **"今天先这样" (onLater) records nothing.** It shows a trace-styled card but no
  trace is saved — a returning user may expect "I chose to rest" to count. Could
  optionally save a gentle recovery trace, or make the non-saving explicit. *(P3)*

## 2. ISFP user
- **Now re-asks mood + energy every time** (`NowFlow` local state resets per
  mount). Remembering the last pick (and offering it pre-selected) removes a
  decision for a returning user — fewer taps, less "being quizzed." *(P2)*
- Peeks + one-primary-action flow feels good; nothing new jarring.

## 3. Tired user at 3 AM
- Late-night gate + Soft Ritual offer on Home **and** Now are solid now. No new
  3AM hazard found. The quiet-hours indicator is honest about doing nothing yet.

## 4. Technical maintainer
- **Traces are append-only and unbounded** — no per-trace delete, and the journal
  grows forever in one localStorage key. Low urgency, but a tidy/delete affordance
  and an eventual size cap are worth it. *(P3)*
- `Opportunity` still isn't persisted (transient) though the schema/serializer
  anticipate it. Fine; note it. *(P3)*

## 5. Future iOS developer
- Core-purity is now **enforced** (Cycle 27) — the precondition is locked. The
  remaining lift (workspaces, move files, retarget `@/`) is the real work and is
  deliberately not an autonomous-tick task. No change.

## Ownership / privacy (extra lens this round)
- **No way to export/keep your traces.** They're the user's "year rings," yet the
  only data action is destructive reset. A copy-to-clipboard / text export of the
  journal ("把你的痕迹存下来") fits the product's soul (your real moments are
  yours) and is safe + testable via a pure formatter. *(P2 — strongest new item)*

## Top fixes to schedule (added to next-steps.md, "Round 2")
1. **P2** Export/keep traces — pure `formatTracesForExport()` + a copy/download action.
2. **P2** Remember last mood/energy in the Now flow (persist + pre-select).
3. **P2** First-open intro card (dismissible), reusing the samples-note pattern.
4. **P3** Per-trace delete (or tidy) + eventual journal size cap.
5. **P3** Optionally record a gentle trace for "今天先这样".
