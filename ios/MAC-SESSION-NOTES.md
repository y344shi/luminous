# Mac session — iOS · macOS · watchOS port (2026-06-28)

**Read me, then decide the two open questions at the bottom.** Everything here is
already committed on branch **`macos`** and pushed; nothing is loose in a working tree.

## TL;DR
The native SwiftUI app now **builds and runs on all three platforms from one Xcode
project**, and the **skins (glass / ocean / paper) are switchable at runtime** and
persisted. Verified by actually building + launching, not by reading.

| platform | build | runs | evidence |
| --- | --- | --- | --- |
| iOS (iPhone 17 Pro sim) | ✅ `BUILD SUCCEEDED` | ✅ launched | `ios/shots/ios-glass.png`, `ios-ocean.png`, `ios-paper.png` |
| macOS (native, my Mac) | ✅ `BUILD SUCCEEDED` | ✅ launched (process stayed up) | shares the exact SwiftUI Home shown in the iOS shots |
| watchOS (Apple Watch S11 46mm sim) | ✅ `BUILD SUCCEEDED` | ✅ launched | `ios/shots/watch-home.png` |

> macOS window screenshot is omitted only because screen-capture/automation is
> permission-gated for a CLI here — the app itself built, signed, validated, and ran.

## What I changed (all on `macos`, based on `ios-glass` @ d8399b0)
1. **Skins are now really switchable** (they were a hard-coded `static var`).
   - Split `Aesthetic.swift` → the pure `enum Aesthetic` (now `Codable`, with
     `label`/`feeling`/`symbol`) stays; the heavy `AestheticField` view moved to
     its own `AestheticField.swift` so watchOS can reuse the enum without the
     Canvas/MeshGradient field views.
   - `AppStore` gained a persisted `aesthetic` (UserDefaults key `tdd.aesthetic`,
     mirroring `introSeen`), `setAesthetic(_:)`, reset handling.
   - `AestheticField` reads `store.aesthetic` → switching re-skins Home live.
   - **Settings → 外观风格** picker added (glass / ocean / paper) on iOS, macOS, watch.
2. **macOS** needed *no* source changes — the upstream `ios-glass` reconciliation
   had already `#if os(iOS)`-guarded the only UIKit spots (`Feedback`, the nav-title
   modifiers) and the project was already `SDKROOT = auto` with `macosx` in
   `SUPPORTED_PLATFORMS`. So macOS "just worked" once verified.
3. **watchOS** is a new target **"Luminous Watch App"** in the same project:
   - Shares the 10 pure-core files (Domain/Store/Scoring/SeedParser/SemanticTime/
     Copy/Theme/DayGrade/Feedback/Aesthetic) via explicit references.
   - New watch-native UI in `ios/LuminousWatch/` (`LuminousWatchApp.swift`,
     `WatchUI.swift`) — the same gentle loop (现在别消失 → 完成/部分/跳过 → 痕迹),
     sized for the wrist, with the skin picker. It is **not** the iPhone layout
     crammed onto a watch.
   - Bundle id `rainymushroom.Luminous.watchkitapp`, companion = the iOS app.

## How to build/run yourself
```bash
# from ios/ in a worktree (NOT the live Xcode copy if Xcode is open — see CLAUDE.md)
xcodebuild -scheme Luminous -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -scheme Luminous -destination 'platform=macOS' build
xcodebuild -scheme "Luminous Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
```
In Xcode: the scheme switcher now shows **Luminous** (iOS/Mac/Vision) and
**Luminous Watch App**.

## ⚠️ Safety — how this was done
Per `ios/CLAUDE.md`, I **never switched branches in your live Xcode copy** (Xcode was
open the whole time). All work happened in a separate worktree:
`/Users/y344shi/Desktop/luminous/wt-macos` on branch `macos`.
**When you pull this onto the live copy, CLOSE Xcode first** (the live copy is also a
couple commits behind `origin/ios-glass`).

---

## ❓ Two decisions I need from you (I proceeded with my best guess; reverse freely)

### 1. "All skins switchable **and on main**" — I did NOT push to `main`. Here's why.
`docs/CONTEXT.md` defines **`main` = the web trunk** (the WSL machine pushes Next.js
there via `git subtree`; it's currently ~56 commits ahead of anything native), and
**`ios-glass` = the iOS/native trunk**. Pushing native Xcode code onto `main` would
collide with the web trunk and likely break the cross-machine sync.

So I read "on main" as **"consolidated on the one native trunk, not scattered across
per-skin branches"** and delivered that: one project, all skins switchable, on the
iOS trunk lineage. **I pushed to `origin/ios-glass` (fast-forward) and to a review
branch `origin/macos`.**

**If you literally meant the git branch `main`**, that's a bigger call (unify web +
native under one trunk?) that affects the WSL machine — tell me and I'll plan it with
you rather than clobber the web main.

### 2. watchOS data is currently **standalone** (its own UserDefaults).
The watch app reuses the full core but stores its seeds/traces in the *watch's* local
UserDefaults — it does **not** yet sync with the phone (no App Group / WatchConnectivity).
For a first cut that's fine (it's a real, working watch app). If you want the watch to
share the phone's seeds/traces, the next step is an App Group + `WCSession`. Say the
word and I'll wire it.

### Smaller notes
- The watch uses a lightweight per-skin **gradient** backdrop (not the full
  Canvas/MeshGradient field) — deliberate, to keep the wrist render cheap. The skin
  still visibly changes. Can upgrade later if you want.
- No app icon set for the watch target yet (builds fine; just no custom glyph).
- I left your recovered `GlassField.swift` etc. untouched; this branch is a clean
  superset of `ios-glass`.

---

## Live backlog — on-device session (2026-06-29)

**Shipped to the device this session**
- Sensor-fusion port (motion + location → weather), `sensorBonus` verbatim, day-line.
- Motion now uses `CMMotionActivityManager` (stationary/walking/automotive) — reliable
  on device (the raw-accelerometer version was weak; "gravity not working").
- Settings → 感受周围 shows a **live sensing-status list** (which senses are active now).
- Wishes are **draggable** + **lean with device tilt (gravity)** + no longer overlap the orb.

**Decision needed**
- **HealthKit (heart-rate → arousal).** The classifiers + wiring are ready, but the
  **HealthKit entitlement requires the PAID Apple Developer Program ($99/yr)** — a free
  Personal Team cannot sign it, so it can't run on the phone as-is. Options: (a) upgrade
  to paid → I enable it for the device; (b) I demo it in the Simulator (free); (c) skip.

**Requested, not yet built (proposed order)**
1. **Auto place type — home / work / mall / outdoor.** Reverse-geocode the coarse
   location (`CLGeocoder`) + nearby POI / building category (`MKLocalPointsOfInterestRequest`)
   → map to `LocationType`. Learn "home" (most-frequent night location) and "work"
   (most-frequent weekday-day location) over time, on-device. Feeds `locationFit`.
2. **Duration + time-histogram analytics per sensed metric.** Log each sensed state with
   timestamps on-device (still/walking/transit, quiet/lively, weather, place), accumulate
   **dwell durations** (e.g. desk-minutes today → `dwellBonus`, mirroring @core/dwell), and
   show a simple histogram (today / this week) per metric. All local, nothing transmitted.

Both are multi-file features; will tackle after the HealthKit decision + confirming the
current on-device build feels right.
