# Reading & Study Suite — progress + ideology (for later agents)

*A handoff note for anyone (agent or human) picking up the scan → read → study →
review → share arc built into Luminous during 2026-07. Read `ARCHITECTURE.md`
first for the app as a whole; this is the deep context for the reading suite.
The living design/queue is `WORD-STUDY-PLAN.md`.*

Last updated: **2026-07-19** (branch `ios-glass` == `main`, tip around `aa00cc0`).

---

## 0. The one-line intent

Let someone scan a foreign **picture book** (esp. a child's book, French → any),
then **read it on-device** — page by page, word by word — with translation,
gentle notes, pronunciation, and **Apple Pencil annotation**, and **share the
annotated book** to another device. Everything **on-device, offline, private**;
the model helps, code decides truth and safety. It is a *life/learning anchor*,
never a productivity drill — same soul as the rest of Luminous (no scores, no
shame, calm).

## 1. The arc (and where each piece lives)

```
扫书 (scan a BOOK)  →  逐字读 (read: page + words + translation + notes + TTS)
     │                        │
     │                        ├─ 批注 (Apple Pencil annotation, per page)
     │                        └─ tap a word → its meaning card (EN + 中文 + 语法/用法/例句)
     ↓                        ↓
  book shelf            分享/隔空投送  ←→  导入一本书   (.luminousbook over AirDrop)
                              ↓
                        [queued] 回顾/复习: word-frequency list + ask-the-book Q&A
```

| Surface | File(s) |
| --- | --- |
| **地图** (a separate travel tool: messy link/text → map pins) | `MapPinboardView.swift`, `MapPinboardAI.swift` |
| **扫书** shelf — scan books, name them, cover = 1st page, import/share | `BookScanView.swift` |
| Book storage (folder per book, sidecar caches) | `BookStore.swift` |
| VisionKit document scanner wrapper | `DocumentScanner.swift` |
| Shareable one-file archive | `BookArchive.swift` (`.luminousbook`) |
| **逐字读** split reader (page ↕/↔ reading, zoom, fonts, TTS) | `BookReaderView.swift` |
| Per-word explanation + page reading-notes (on-device) | `WordStudyAI.swift` |
| Apple Pencil per-page annotation | `PageAnnotator.swift` |
| Translation + Vision OCR (reused) | `Translate.swift`, `TranslateView.swift` |

## 2. Data & file structure (the "shareable structure for annotation")

A book is a **folder** `Documents/Books/<id>/`:
- `meta.json` — `{ id, name, createdAt }` (first page = cover)
- `page-0000.jpg`, `page-0001.jpg`, … — pages, **upright** (EXIF baked in on save)
- Per-page **sidecars**, all lazily cached & re-derived, keyed by page basename:
  - `.txt` — Vision OCR text
  - `.trans` — `{english, chinese}` on-device translation
  - `.notes` — `[String]` short reading notes
  - `.ann` — **PKDrawing** data (editable Pencil annotation)
  - `.annpng` — rendered transparent PNG of the annotation (display overlay)
- Rotating a page **clears all its sidecars** (they no longer align).

**`.luminousbook`** = one **binary property list** (`BookArchive`) holding the
whole book (pages + all sidecars) — no zip lib, no doc-type registration needed.
`ShareLink`/`UIActivityViewController` out (AirDrop), `.fileImporter` +
`BookArchive.importArchive` in. Round-trips losslessly; **annotations travel**.

## 3. Ideology / design rules specific to this suite (do not break)

- **On-device, offline, private.** OCR = Apple Vision; translation/notes/word
  cards = FoundationModels; TTS = AVSpeech (Siri voices); annotation = PencilKit.
  Nothing about a book leaves the device except when the user explicitly shares.
- **The house LLM law still holds:** every model call is `@Generable` structured
  output **+ deterministic fallback + `ForbiddenWords.passes`** on anything shown.
  In the **Simulator the model is always absent** → the UI must degrade to a calm
  note, never a crash or blank. (This is why device installs matter — see §5.)
- **Degrade off-iOS.** PencilKit / VisionKit / camera are iPad/iPhone affordances;
  gate them `#if canImport(...) && os(iOS)` and keep the macOS build green.
- **Calm, count-free, bilingual.** Chinese-first UI voice; explanations in EN +
  中文; no scores, no "N/total", no nagging. A page you glanced at is fine.
- **Read-first, tap-optional.** Translation + notes are shown *already* so you can
  read without tapping each word; tapping a word is for going deeper, not required.
- **Caches are derived, never precious.** Any sidecar can be deleted and regened.
  The image + annotation are the only irreplaceable bytes; the archive carries them.

## 4. State: shipped vs queued

**Shipped & on device (iPhone 17 Pro + iPad Pro):**
- Books shelf; VisionKit auto-capture scanning; name + cover.
- Split reader: portrait (page over reading) / landscape (page left, reading
  right); pinch-zoom page (double-tap reset, 1-finger pan when zoomed); draggable
  page handle + **dotted** handle between 原文 and explanation; reference-card
  font A−/A+.
- Bilingual translation shown already + a few 读书笔记; per-sentence / word / line
  **Siri pronunciation** in the detected language (`NLLanguageRecognizer`).
- Tap a word → its card (EN + 中文 + 语法/用法/例句).
- **Apple Pencil annotation** per page (composited onto the page so it zooms with
  it) + rotate page (+ apply-to-all).
- **Share/import** annotated books via `.luminousbook` (AirDrop → 导入一本书).

**Queued (see `WORD-STUDY-PLAN.md` §6b/§6c — priority order):**
1. **Register the `.luminousbook` UTI** so an AirDrop'd book **opens Luminous on
   tap** (instead of via 导入). Needs an `Info.plist` with
   `UTExportedTypeDeclarations` (`net.luminous.book`, conforms `public.data`,
   ext `luminousbook`) + `CFBundleDocumentTypes`, wired via `INFOPLIST_FILE` on
   the **app target only** (the two `rainymushroom.Luminous` configs, NOT the
   `.watchkitapp` ones) while keeping `GENERATE_INFOPLIST_FILE = YES` (Xcode
   merges the generated keys onto the file — verify the built Info.plist has BOTH
   the doc types AND e.g. `CFBundleDisplayName`). Plus `.onOpenURL` in
   `LuminousApp` → `BookArchive.importArchive` → jump to 扫书. **Requires Xcode
   CLOSED** (pbxproj edit under an open project can corrupt it — hard rule).
2. **回顾/复习 (book as a database):** word-frequency list (deterministic from the
   `.txt` sidecars — works in Simulator) + **ask-the-book** Q&A (on-device model
   with the book text as context; plain `LanguageModelSession.respond` +
   `ForbiddenWords`).
3. **Phrase-aware tap + drill-down:** tap the most meaningful *few words* together;
   re-tap a highlighted region to subdivide (phrase → words → morphemes).
4. **Preprocess pages** (OCR/tokenize ahead of the tap so sentences show instantly).
5. **Two-finger swipe to page while zoomed** (needs a custom UIKit pager; TabView
   can't tell touch counts apart).
6. Persist word cards per book + the two-axis deepening / dwell-adaptive / review
   from the original `WORD-STUDY-PLAN.md`.

## 5. How to build & put it on a device (the practical gotchas)

- Green gate: `cd ios && swift test` (83) + `xcodebuild -scheme Luminous
  -project Luminous.xcodeproj -sdk iphonesimulator -destination '…iPhone 17 Pro'
  build`. macOS at milestones. FoundationModels/PencilKit/VisionKit **only truly
  run on device** — always install to the phone/iPad to verify the AI + Pencil.
- **Signing:** the project's own team is **`S29PL5D9HM`** (Apple ID
  yuxuanshi152214). Do **not** force the old keychain team `DDL4RY4YK6`. Device
  build: `xcodebuild … -sdk iphoneos -destination 'generic/platform=iOS'
  -allowProvisioningUpdates -derivedDataPath build/device build`. The
  `project.pbxproj` carries `DEVELOPMENT_TEAM = S29PL5D9HM` locally — **kept
  uncommitted on purpose** (don't commit the personal team).
- **Install:** `xcrun devicectl device install app --device <UDID>
  build/device/Build/Products/Debug-iphoneos/Luminous.app`. Devices:
  iPhone 17 Pro 半岛旅盒 `34512253-E1CA-55A0-805C-DD6A1C6EB3CD`; iPad Pro
  `AAE0E214-67F6-5810-8A19-C0005DBC96CB`.
- **Common install failures:** device **locked** → `kAMDMobileImageMounter
  DeviceLocked` (unlock it); **DDI not mounted / not located** → the device isn't
  actually on USB/Wi-Fi (check `system_profiler SPUSBDataType` / `devicectl list
  devices` state == available/connected). A retry-until-available loop works well.
- **6 tabs → on iPhone 扫书 sits under the system "More" tab** (tab bar overflow).
  Tidy-up owed: trim/reorganize the tab bar (maybe fold 地图/扫书 under a hub).

## 6. Repo / workflow reminders

- Two branches only: **`main`** (trunk, worktree `wt-aware`) and **`ios-glass`**
  (the live Xcode copy at `net/luminous`). Push habit: `git push origin ios-glass`
  then `git push origin ios-glass:main` (or the reverse) — keep them equal. A flat
  clean clone also exists at `~/Desktop/luminous-clean` (on `main`).
- **Never** rewrite files under the open Xcode copy via git (checkout/merge/rebase/
  stash) — it corrupts the project. Read-only git is fine. Commit small,
  single-quoted `-m`, Co-Authored-By trailer.
- `output/` and `tools/` under `ios/` are intentionally untracked (earlier PDF
  work) — leave them.
