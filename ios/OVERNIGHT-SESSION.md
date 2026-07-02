# Overnight session — "aware" (2026-06-30 night) — COMPLETE ✅

Branch **`ios-aware`** in worktree `/Users/y344shi/Desktop/luminous/wt-aware`
(base: `macos` @ `717995c`). Your live Xcode copy and `wt-macos` were never touched.
Rationale: `ios/VISION-AUDIT.md`. **All 13 cycles shipped, every commit green
(43 `swift test` + iOS + macOS + watch builds) and pushed to `origin/ios-aware`.**

Proof shot: `ios/shots/aware-home.png` — the scout live-pairing a real nearby
place ("New Century Home · 50m") with a wish on a shooting star, real weather
in the day-line.

## What shipped (one commit per cycle)

| cycle | commit | what |
| --- | --- | --- |
| C0 | `aware 0` | SwiftPM test harness (`cd ios && swift test`), 15 safety-pinning tests; SensorClassifiers split; **fixed pre-existing watch build break** (LearningLog missing from watch target since 0c56457) |
| C1 | `aware 1a-1c` | **SwiftData multi-profile DB**: hybrid payload-JSON records, CloudKit-ready shape; migration from tdd.* (never deleted — rollback safe); dual-write mirror; multi-garden switcher in Settings (花园); append-only EventRecord log |
| C2 | `aware 2` | Life-event log wired to sensed transitions; sensing cadence fixed (was ONE fix per launch → 5-min foreground timer + scenePhase); Rhythm.swift dwell/histograms; Settings dwell line |
| C3 | `aware 3` | **LLM seed parser** (@Generable, tone rules, closed-enum validation, ForbiddenWords, keyword fallback); ForbiddenWords ported from web core; NowView finally reads the sensors |
| C4 | `aware 4` | **Learned places**: ~150m cells (raw coords never stored), home = modal night cell, work = weekday-day cell; locationHint real (was hardcoded .outdoor) |
| C5 | `aware 5` | **Proactive nearby scout**: active wish × fitting place ≤800m → shooting star with place badge; tap opens the existing wish; POI search 12 results, re-search on >250m/>15min |
| C6 | `aware 6` | **Recurrence**: sleeping wishes resurface at their median cadence; modal done-time affinity; ≥3 skips in a context quietly lower the offer there (never shown, never punitive); serendipity now stable per (seed, part-of-day) |
| C7 | `aware 7` | **Mentality estimate**: model reads day aggregates → {restlessness, depletion, openness}, ONE clamped ±0.2 term, cached 1h, neutral fallback, never a label |
| C8 | `aware 8` | **Executors**: ReviewQuiz (learned-word quiz, logged), CreationSpark (opening line from today's traces), ConnectionDraft (one honest sentence, copy-only), RecoveryBreath (no model); merge widened to all same-category pursuits |
| C9 | `aware 9` | **Notifications, default OFF**: pure NudgeGate (quiet hours wrap midnight, daily cap, late-night absolute); one pending nudge ever, cancelled on return; quiet-hours UI (深夜永远不会打扰，这条规则改不了) |
| C10 | `aware 10` | Reason-writer (model re-phrases WHY, never WHAT, never late-night copy) + LLM moment suggestions (closed categories, filtered, static pool floor) |
| C11 | `aware 11` | Weekly review: 回看这一周 atop 痕迹 — two-three gentle sentences from the week's traces + learning |
| C12 | — | this wrap: tri-platform green, shot, docs |

## Decisions taken on your behalf (reverse freely)

1. **"Database for multi user" = SwiftData local multi-profile** (multiple
   gardens, switchable), CloudKit-ready schema. NOT a cloud backend — real
   CloudKit sync + accounts need the **paid** dev program, and
   `docs/database-plan.md` warns against blocking the core loop on infra.
2. **Old UserDefaults data is dual-written, never deleted** — reverting
   Store.swift restores everything. The watch keeps pure UserDefaults.
3. **Notifications wired but OFF by default**, and the only trigger tonight is
   the honest one: leaving the app while a wish is ripe schedules ONE soft
   line for the wish's natural hour. (True arrive-at-a-place nudges need
   Always-location / background modes — deliberately not taken.)
4. Merge for non-language pursuits relies on the LLM only (keyword fallback
   stays language-only); unsure → always plants fresh.
5. ReviewQuiz picks from the oldest-learned words rather than true per-word
   spaced-repetition dates — good enough to be useful; upgrade path below.

## Advice / open questions for the morning

- **Simulator note**: everything LLM (parser upgrade, quiz, sparks, mentality,
  reason-writer, weekly review) silently falls back in the sim — test those on
  the iPhone (I can build+install over Wi-Fi when you're up; unlock helps).
- **Multi-garden + music/skins**: skin & music are per-garden prefs now —
  switching gardens can re-skin the app. Intended; say if it feels wrong.
- **Nudges**: to try them, Settings → 提醒 on (it asks permission then), add a
  wish, leave the app. One notification, no sound, at a fitting hour.
- **Upgrade paths queued**: per-word spaced-repetition dates; CLVisit/Always
  location for true place-transition nudges (needs your OK — it's a bigger
  privacy ask); CloudKit sync flip-on (needs paid program); watch App Group
  sync; freeMinutes inference from rhythm gaps.
- **pbxproj**: watch target gained LearningLog/Recurrence/Mentality refs; the
  test package lives at `ios/Package.swift` + `ios/CoreTests/` (Xcode never
  sees it; run `cd ios && swift test`).

## The architecture law (now enforced by tests)

The linear scorer is the auditable spine; every intelligence source — sensors,
places, history, mentality, LLM — is one clamped additive term. Hard gates live
in code, never prompts (the late-night gate is pinned by 3 tests). Every LLM
feature: @Generable structured output + deterministic fallback + ForbiddenWords.
