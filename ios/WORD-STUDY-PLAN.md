# 逐字 / Word-Study Card — design & plan

*An interactive, on-device-AI language-study surface. You read a scanned book
page (扫书) or any text; the words are segmented by meaning; tap one and a card
rises from the bottom that explains it and keeps deepening the longer you stay.
Everything is generated locally (FoundationModels), saved so it's never lost, and
turned into a per-book word database you can review later against the very
sentences you met the word in.*

Status: **spec only — not built yet.** Captured 2026-07-12 from the user's vision.
Companion to `BUILD-TODAY-PLAN.md`. Feeds off `扫书` (`BookScanView`) + the
`拍照翻译` OCR/translate pipeline (`TranslateView`, Vision + FoundationModels).

---

## 1. The vision (as described — nothing dropped)

**Books & pages**
- Scanning **saves a book** (its **first page = cover**); pages are **auto-oriented**
  and added as entries under the **book name**; more scans append to the book.
- Opening a book is a **split reader**: the page **on top** (swipe page by page), a
  **draggable divider**, the paragraph **below** as clickable tokens, and the
  **explanation region in the lower half** (nothing shown up front — only on tap).

**Reading & segmentation**
- Local AI produces the explanations, in an **iterative** way (it deepens as you engage).
- The **parsed original text is highlighted** (you see the tokens over the source).
- Each **word or phrase is segmented by its meaning** (meaning-units, not just spaces).
- **Words have meaning together:** a tap should explain the **most meaningful few words
  as a phrase** (highlighting the whole group); tapping an **already-highlighted region
  subdivides** it into smaller units (phrase → words → morphemes).
- **Read aloud with a French voice** (for a French picture book).

**The card (rises from the bottom when a word is pressed)**
- Shows the **most basic meaning in English and Chinese** — plus **grammar, usage,
  variations, examples**.
- **Scrolls in two directions:**
  - **Scroll DOWN → breadth.** Generates **more variety** of explanation, **appended**
    to the card; connects the word to **different words**.
  - **Scroll RIGHT → depth.** **Focuses the current scope** and explains **more in
    depth, more granular, more microscopic** — e.g. meanings **in different tenses**,
    **comparison to English words**, the **词根 (root/etymology)**.
- **Dwell-adaptive length:** the **longer you stay on a card, the more length is
  generated** — scaled by your **average time-per-word on this card**, compared to a
  **baseline collected over past cards**. (Linger → it writes more; skim → it stays short.)

**Persistence & review**
- **Every generated card ("lecture card recording") is saved** so generation is never
  lost, and **cards are stored per word, persistently**.
- A **database of all words for this book** is built **as you learn**, for **future
  review sessions**.
- In review you can **test yourself on the different sentence-occurrences** of a word
  (seeing it in the real sentences you met **brings the memory back**).
- **Tap a recalled sentence → jump to the page** where you learned it, with the
  **per-word elaboration cards** in place.

---

## 2. How it fits Luminous (the house patterns)

- **On-device only.** All generation via **FoundationModels** (`@Generable`), the
  house pattern: structured output + **deterministic fallback** (a dictionary/gloss
  stub when the model is away, always true in the Simulator) + **`ForbiddenWords`**
  on anything shown. The LLM decides content; code decides truth/safety.
- **Input = OCR text.** From a `扫书` page (`ScannedPagesStore`) or the `拍照翻译`
  Vision recognizer. So this is the "study" half of *scan → study*.
- **Persistence = SwiftData**, hybrid payload-JSON records (the D18 pattern — add
  fields without migrations), `profileID`-scoped like everything else.
- **French TTS** via the existing `Speaker` (AVSpeechSynthesis) with an `fr-FR` voice.
- **Adaptive length** is a small, auditable heuristic (dwell vs baseline) — the same
  spirit as the linear scorer: one measurable signal, clamped, not a black box.

---

## 3. Proposed data model (SwiftData, per profile)

- **`StudyBook`** — a scanned book / study set: `id`, `title`, `createdAt`, page refs.
- **`StudyPage`** — `bookId`, the scanned image ref, `ocrText`, `language`,
  `tokens: [Token]` (segmented, with char ranges) so highlights are stable.
- **`Token` / `WordOccurrence`** — `surface` (as printed), `lemma` (dictionary form),
  `pageId`, `sentence`, `range`. The index that powers "every sentence this word
  appeared in" + jump-to-page.
- **`WordEntry`** (per `lemma`, per book — maybe also a global view) — the persistent
  **card**: `base` (EN + 中文 gloss, grammar, usage, variations, examples) plus
  **`breadthLayers: [Layer]`** (appended on scroll-down) and **`depthLayers: [Layer]`**
  (appended on scroll-right: tenses, EN-comparison, 词根…). Each layer stores its
  generated text so it's **never regenerated or lost**. Plus `occurrences: [ref]` and
  a light **review schedule** (next-due, ease) for spaced recall.
- **`DwellStat`** — per-card time totals + a rolling **baseline** (avg seconds/word
  across past cards) that drives how much new length to generate.

---

## 4. Interaction spec (the card)

1. Tap a highlighted word → a **bottom card** slides up (a `.presentationDetent`
   sheet or a custom bottom panel over the page).
2. **Base layer** shows immediately — from the persisted `WordEntry` if we've met it,
   else generated once (with the fallback gloss as the floor).
3. **Scroll ↓ (breadth):** each pull generates the next breadth layer (another sense,
   related words, more examples) and **appends** it; persisted.
4. **Scroll → (depth):** horizontal paging; each page is a deeper/narrower layer
   (this tense, vs the nearest English word, the 词根); persisted.
5. **Dwell loop:** while the card is open, accumulate time; when dwell exceeds the
   personal baseline for this card, pre-generate the next layer so lingering yields
   more without a tap.
6. **Read-aloud:** a French-voice play button on the word and on its sentence.

---

## 5. Review & recall

- A **per-book word list** (built as you tap). Each entry → its card + every sentence
  it appeared in.
- **Recall test:** show the word (or a sentence with it blanked) and ask you to recall;
  reveal the real sentences from the book as the memory cue; grade updates the schedule.
- **Jump-to-context:** tap any recalled sentence → open that `StudyPage` with the
  per-word cards live.

---

## 6. Phased build plan (one green slice per cycle — device-verified)

- **A · Segment & highlight.** OCR text → `@Generable` segmentation into meaning-units
  (fallback: whitespace/punctuation split) → highlighted tokens over the page. Tap a
  token → a **base card** (EN + 中文 + grammar/usage/examples), fallback gloss floor.
  Persist `StudyPage` + `WordEntry.base`.
  **→ first slice SHIPPED (`StudyReaderView` + `WordStudyAI`):** open a 扫书 page →
  Vision OCR → tappable words (whitespace split for now) → tap → a bottom base card
  (EN/中文/语法/用法/例句) from the on-device model, session-cached. **Still to do in A:**
  LLM *meaning*-segmentation (phrases; CJK), and **persistence** (currently in-memory).
- **B · Two-axis deepening.** Scroll-down breadth layers + scroll-right depth layers
  (tenses / EN-comparison / 词根), each generated on demand and **persisted** (never lost).
- **C · Dwell-adaptive length.** Track per-card dwell + rolling baseline; longer stay →
  more layers auto-generated.
- **D · Per-book word database.** The word list + occurrence index + a book picker
  (tie to `扫书` books).
- **E · Review sessions.** Recall tests over occurrences + jump-to-context.
- **F · French TTS + polish.** `fr-FR` voice for word/sentence; audio caching if wanted;
  a11y + Reduce-Motion.

Each phase: keep any adaptive heuristic auditable, every LLM call `@Generable` +
fallback + `ForbiddenWords`, SwiftData hybrid records (no migrations), green gate,
commit small, verify on device (FoundationModels + French voice are device-only).

---

## 6b. Queued for the NEXT update (asked 2026-07-12, not yet built)

- **Phrase-aware tap + drill-down.** A tap explains the **most meaningful few words
  together** (highlight the whole phrase); tapping an **already-highlighted region
  subdivides** it (phrase → words → morphemes). Needs LLM meaning-segmentation of the
  line into phrases + a per-selection granularity state.
- **Preprocess pages.** OCR + tokenize **ahead of time** (right after a scan, and/or
  background-preload all pages on open) so the sentence shows **instantly** — never a
  wait on tap/page-turn. (Today OCR is cached lazily on first view.)
- **Sentence pronunciation (Siri voice).** A play button per **sentence** (and the
  page), reading it aloud in the line's **detected language** (French etc.) via the
  existing `Speaker` (AVSpeechSynthesis) — reuse `speaker.toggle(id:text:language:)`
  with an `NLLanguageRecognizer`-detected BCP-47 code.
- Plus the standing Phase A remainder: **persistence** of cards (never lost) + the
  per-book **word database**, then B (two-axis deepening) → C (dwell) → E (review).

- **Book as a database + review + ask (asked 2026-07-12).** Each book already
  stores per-page OCR (.txt), translation (.trans), and notes (.notes) sidecars —
  treat that as the book's corpus. Build a **回顾/复习** surface:
  - **Word-frequency list** — every word across the book, ranked by how often it
    occurs (deterministic from the OCR text; tap → its word card). "Lists all words
    in their occurring repetitiveness."
  - **Ask the book** — a question box answered by the on-device model with the
    book's text as context (grammar, context, plot, review). Use
    `LanguageModelSession(instructions:).respond(to:).content` (plain text, like
    Translate.plainTwoStep) + `ForbiddenWords`; truncate the corpus to the context
    window (picture books fit; long books need chunking/summary later).
  - Persist word cards per book so review reuses them (ties to the standing word DB).

## 7. Decisions (2026-07-12) + remaining questions

**Decided:** ① **Any language → EN + 中文** (auto-detect the source, like 拍照翻译).
② **The reader opens from a 扫书 page** (tap a scanned page → 逐字读), no new tab.
Defaults taken: custom bottom card; per-book word DB; card *text* persisted first,
TTS audio caching later.

Remaining to confirm as we go:

1. **Language focus.** French source with English + Chinese glosses (given the French
   voice)? Or general multi-language?
2. **"Recordings" =** the generated card *text* saved (definitely), and also **cached
   TTS audio**? (Audio caching is optional extra storage.)
3. **Word DB scope.** Per-book (recommended, matches "for this book") with an optional
   global roll-up, or global from the start?
4. **Card surface.** A bottom sheet with detents (native, quick) vs a fully custom
   bottom panel (more control over the two-axis scroll feel)? The two-axis scroll
   (↓ breadth, → depth) likely wants a **custom `ScrollView`/`TabView` combo**.
5. **Where it lives.** Inside a `扫书` page (tap page → read/study), or its own tab?
