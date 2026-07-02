# Vision audit — from life-anchor to daily-life-aware companion (2026-06-30)

An honest read of where the app's ideals stand in the code today, and a concrete
map for the three asks: **on-board LLM intelligence · deeper awareness · long-term
history awareness** — without ever betraying the philosophy that makes this app
worth building.

---

## 1. The ideal, restated (so we can audit against it)

From `docs/product-philosophy.md`: this is a **life-anchor**, not a productivity
tool. Seed = a soft wish; Context = weather and soil; Opportunity = the moment it
can sprout; Trace = today's growth ring; **AI = the wind that helps you see the
moment**. The one question is not "how productive were you" but *"今天有没有一个
瞬间，你是真的在场的？"*

The recent direction adds a second identity the philosophy doc doesn't yet name:
the AI is becoming not just the wind but **a pair of hands** — it picks the three
French words, translates the menu photo, judges whether a new wish continues an
old pursuit. Call it the **executor** role: *AI helps you DO the wish, right here,
so the bar drops from "start the task" to "accept the help."* This is the app's
real differentiator and it is philosophically sound — as long as the executor
serves the wish and never becomes a taskmaster.

## 2. Audit — what the code actually honors today

**Held strongly (verified in code):**
- **Late-night safety is a true hard gate**, enforced in *code* at three
  independent layers: `Scoring.rankSeeds` filters unsafe seeds, `Suggester`
  returns only stop-loss suggestions, `nearbyAppropriate` hides outing places.
  LLM output can never bypass it. This layering is exactly right — keep it.
- **Partial always counts; skips never shame.** `CompletionKind.partial` writes a
  warm trace; completion puts a seed to `.sleeping`, never deletes it.
- **Minimum action everywhere**; traces are sentences, never a scoreboard.
- **Privacy-first sensing**: raw signals are classified coarse on-device and the
  raw is forgotten; only a coarsened coordinate ever leaves (open-meteo).
- **LLM discipline** (new, and good): every model feature so far follows one
  pattern — structured `@Generable` output, deterministic fallback
  (`LearningMerge.keywordChoice`), graceful degradation when unavailable.

**Honest gaps between ideal and implementation:**
- **The "context" is mostly a clock.** `mood`/`energy` come from `lastPick` —
  whatever the user tapped days ago in NowFlow. `freeMinutes` is almost always
  nil. So of the seven scoring terms, the ones carrying real live signal are
  timeFit and the sensor/place bonuses; moodFit runs on stale self-report.
- **History exists but nothing reads it.** `traces` (500), `learningHistory`
  (300), `learnedVocab` are write-mostly. `freshness()` only looks at status —
  the tree never reads its own rings. No recurrence, no "you tend to do body
  wishes at 8am", no spaced review of learned words.
- **Serendipity is re-rolled every render** (`rng()` per score) — rankings and
  reasons can shift under the user between two opens a minute apart.
- **Dormant ideals**: `Settings.quietHours / maxRemindersPerDay / nudgesEnabled`
  exist, but no notification pipeline uses them. The app can only be kind when
  the user happens to open it — a life-anchor should occasionally reach out
  *at the right transition* (gently, capped).
- **The suggestion pool is hard-coded** (7 static suggestions). Fine as a floor,
  but the moment-awareness it feigns is shallow.
- **SeedParser is keyword-mock** — a wish like "想在雨天给妈妈写封信" parses
  poorly, so the seed's categories/triggers (which drive everything downstream)
  are weaker than they need to be.
- **iOS-only drift**: `LearningLog`/executors exist only in Swift; the web `lib/`
  parity ideal (future `packages/core`) needs a port-back pass eventually.

## 3. Direction A — deeper daily-life awareness

The current `ContextSnapshot` is an *instantaneous* reading. True daily-life
awareness = **rhythms + transitions**, not snapshots. Layers, in build order:

1. **Unified on-device event log** (the substrate for everything below).
   Append-only, compact: state transitions (`still→walking`, place-kind enter/
   leave, weather change) and outcomes (complete/partial/skip **with the context
   snapshot at that moment**). Raw events retained ~90 days, then distilled into
   aggregates kept forever. Local only; export/erase in Settings.
2. **Dwell histograms** (already queued in MAC-SESSION-NOTES): per-metric
   dwell durations per hour-of-week → "desk-minutes today", "outside-minutes
   this week". Feeds a `dwellBonus` and the Settings sensing view.
3. **Learned places**: home = modal night cell, work = modal weekday-day cell
   (coarse geohash frequency, on-device). Finally makes `locationFit` real
   instead of guessed; unlocks "arriving home" as a moment.
4. **Rhythm priors**: per hour-of-week distributions of activity/place →
   "Tuesday 21:00 you're usually home and still". Replaces the bare clock as
   the meaning of `semanticTime`, and lets us *infer* freeMinutes from typical
   gaps instead of asking.
5. **Transitions as the recommendation moment.** The best time to hand back a
   wish is a seam: arrived home, left transit, weather cleared, long stillness
   ended. `CLVisit`/significant-change monitoring → a *local* notification,
   strictly gated by the already-existing (dormant) `quietHours` +
   `maxRemindersPerDay` + the late-night gate. This turns the dormant settings
   into the product they promise.
6. **When available**: HealthKit sleep/arousal (needs paid program — decision
   already logged); mic loudness (permission-gated, classifier already ported).
7. **Gradually stop asking mood.** As rhythm + sensed layers mature, `lastPick`
   becomes a fallback, not the primary mood source. Ask less, sense more —
   asking is friction and staleness.

## 4. Direction B — on-board LLM as the intelligence core

Architecture rule to lock in now (it's implicitly true already — make it law):

> **The linear scorer stays the auditable spine. Every intelligence source —
> sensors, places, history, LLM — contributes one clamped additive term.
> Hard gates live in code, never in prompts. Every LLM feature has a
> deterministic fallback and its output passes the forbidden-words filter.**

With that spine, the model can be trusted with much more:

1. **LLM seed parser** (highest leverage, lowest risk). Replace keyword
   `SeedParser` with a `@Generable` structured parse (categories, minimumAction,
   duration, energy, triggers) with tone constraints in instructions; keyword
   parser stays as the fallback. Every downstream system improves because seeds
   are richer. The `LearningMerge` pattern is the template.
2. **Mentality estimate** (the queued histograms → LLM idea, formalized).
   Feed the day's aggregates (dwell, transitions, weather, recent outcomes) →
   structured estimate {restlessness, depletion, openness} → **one clamped
   bonus term** (like `sensorBonus`, ±0.25) + gentler phrasing. The LLM reads
   the day; the scorer still decides.
3. **Reason-writer.** `buildReason` templates → model-phrased reasons from the
   ScoreBreakdown + context, post-filtered by forbidden words, template
   fallback. The model never chooses *what*, only *how to say it warmly*.
4. **An executor per category** — generalize what vocab/translate started.
   A small `WishExecutor` protocol (applies(seed) → card UI → structured LLM
   call → history entry):
   - *learning*: vocab picker ✅, photo translate ✅, **micro-review quiz** from
     `learnedVocab` (spaced repetition: 1 review + 2 new).
   - *creation*: a single opening line seeded by today's traces/weather.
   - *connection*: draft one honest first sentence to send (never auto-sends).
   - *recovery/body*: a 3-breath script / 5-minute stretch sequence.
5. **Generalized merge.** `LearningMerge` → `PursuitMerge` for all categories:
   any new wish is judged (LLM, keyword fallback) against existing anchors, so
   every long-term pursuit accumulates one history instead of duplicating.
6. **LLM-suggested moments** (replaces the static suggestion pool's shallowness):
   given context + rhythm, the model proposes up to 3 suggestions *in the app's
   voice*; code-side filters enforce late-night gate, category whitelist, and
   forbidden words; static pool remains the fallback.
7. **Weekly gentle review**: one warm paragraph from the week's traces +
   learning history — "这周你三次在傍晚出门走了走". Not stats. A sentence that
   proves the weeks aren't disappearing either.

## 5. Direction C — long-term history awareness

1. **Per-seed memory** (replaces `freshness()`): completion count, typical
   completion time-of-day, median gap between completions, last-3 outcomes.
   → a **recurrence model**: sleeping seeds resurface at their natural cadence
   ("you water this wish about every 4 days"), scored via a `historyBonus`.
2. **Fit-learning, never punishment.** If a seed is skipped repeatedly in a
   given context, *lower how often it's offered in that context* — never surface
   "you skipped this 5 times". The philosophy line is: skips teach the wind
   where not to blow, they are never held against the user.
3. **Spaced repetition** over `learnedVocab` (each word gets a next-review date;
   the vocab executor mixes review + new). Learning history stops being a diary
   and starts compounding.
4. **The trace becomes readable by the tree.** Mentality estimate (4.2) and
   recurrence (5.1) both consume the event log — the rings finally inform the
   growth.
5. **Sync, local-first**: App Group + WatchConnectivity for the watch (decision
   already open in MAC-SESSION-NOTES); later CloudKit private DB if multi-device
   matters. Aggregates sync; raw events stay on the device that sensed them.

## 6. Proposed build order

| phase | items | why first |
| --- | --- | --- |
| **P0** | Event log + dwell histograms (§3.1–3.2) | substrate for every other direction; already queued |
| **P1** | LLM seed parser (§4.1) · learned places (§3.3) · per-seed recurrence (§5.1) | biggest recommendation-quality jump per line of code |
| **P2** | Mentality bonus (§4.2) · review-quiz + creation/connection executors (§4.4) · generalized merge (§4.5) | the executor identity matures |
| **P3** | Transition nudges w/ quiet-hours (§3.5) · reason-writer (§4.3) · LLM suggestions (§4.6) · weekly review (§4.7) | outward-facing; needs P0–P2 trust |

## 7. Risks to hold the line on

- **Executor ≠ taskmaster.** Executors must stay *offers inside an opened card*,
  never auto-run, never notify "your quiz is ready". The wish invites the help.
- **A mentality estimate is a guess, not a diagnosis.** Never show it as a
  label ("you seem depleted"); it only tilts scoring and softens phrasing.
  The AI-never-diagnoses rule extends to implied diagnoses.
- **Notification restraint is the product.** One transition nudge on a good day,
  zero on most days. `maxRemindersPerDay` default should stay tiny.
- **Score stability**: seed the serendipity rng per (seed, hour) so two opens a
  minute apart agree with each other.
- **Keep parity portable**: new pure logic (event log, rhythm, recurrence,
  merge) should stay React-free/Swift-pure mirrors of a future `packages/core`,
  as `lib/` ↔ `Luminous/` already do.
