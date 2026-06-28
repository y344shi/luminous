# Workload — iOS sensor-fusion port (for the Mac/Xcode agent)

**Branch:** `ios-glass` (the single iOS trunk). Build + run in Xcode on the Mac.
**Goal:** mirror the web's multi-sensor context-fusion ranking in the SwiftUI app,
so iOS is *keen* about which tiny action fits now — and so **heart rate** (web
can't read it) finally comes alive via HealthKit.

This is the iOS counterpart of the web sensing work. Match the web behavior; don't
invent new ranking rules.

> **Update (post-extraction):** the whole framework-free brain now lives in
> **`@luminous/core`** (`packages/core/`) — recommender + classifiers + `scoreSeed`
> with the sensor/dwell/weather/battery bonuses, guarded React-free *and* app-free.
> Two ways to build the native app:
> - **React Native (recommended):** add `@luminous/core` as a workspace dep and
>   **consume the ranking + classifiers directly — zero reimplementation.** Only the
>   *sampling* is platform-specific (expo-sensors / expo-av / HealthKit / CoreLocation),
>   feeding the same pure classifiers. This is the whole point of the extraction.
> - **SwiftUI:** reimplement in Swift, mirroring `@core` exactly (the rules below).
> The web fusion has grown past this brief — also port **dwell** (`@core/dwell`),
> **weather** (`@core/weather`), and **battery** (`@core/battery`) bonuses.

## Read first (the source of truth — now in `@luminous/core`)
- `@core/sensors` (packages/core/sensors.ts) — pure classifiers + thresholds (port verbatim):
  - `classifyActivity(magnitudes)` → `still | walking | transit` (mean-abs-deviation: `<0.6` still, `<3.5` walking, else transit; needs ≥4 samples)
  - `classifyAmbient(rms)` → `quiet | lively` (`rms >= 0.08` → lively)
  - `classifyArousal(bpm, resting=70)` → `calm | elevated` (`bpm >= resting+18` → elevated)
- `@core/scoring` → `sensorBonus` (+ `dwellBonus`/`batteryBonus`) — the **exact** rules to mirror:
  - transit: `+0.1` if `estimatedDurationMin <= 10`; `-0.12` if focus(learning|creation) & `locationType == computer`; `+0.05` if recovery|body
  - walking: `+0.1` if outdoor | exploration | body
  - still: `+0.05` if focus
  - quiet: `+0.1` if focus | aesthetic
  - lively: `+0.1` connection; `+0.05` recovery; `-0.06` focus
  - elevated: `+0.12` recovery|body; `-0.08` if energy high | exploration
  - calm: `+0.06` focus
  - **clamp to ±0.25**, add into `scoreSeed` total alongside `triggerBonus`
- `@core/types` → `ContextSnapshot.activity/ambient/arousal/deskMinutesToday/batteryLow` (optional)
- `components/home/shared/useSensors.ts` — the web sampling model (passive motion + opt-in mic). Note the **both clickable + automatic** behavior (see below).
- `@core/ambient` → `ambientLabel(...)` appends `走着/在路上` + `周围很安静/周围有点热闹` when sensed — surface the same on iOS.

## Build on iOS (`ios/Luminous/`)
1. **Domain** (`Domain.swift` or new): add `enum Activity {still,walking,transit}`,
   `enum Ambient {quiet,lively}`, `enum Arousal {calm,elevated}`; add optional
   `activity/ambient/arousal` to the context snapshot struct.
2. **Sensors.swift** (new) — derive on-device, mirror thresholds:
   - **Motion**: `CMMotionManager` accelerometer (or `CMMotionActivityManager`) →
     `classifyActivity`. Passive/automatic (no permission for raw accelerometer;
     `CMMotionActivity` needs Motion & Fitness permission).
   - **Ambient loudness**: `AVAudioEngine`/`AVAudioRecorder` tap → RMS → `classifyAmbient`. Needs mic permission (opt-in).
   - **Heart rate → arousal**: **HealthKit** `HKQuantityType(.heartRate)` (latest sample / `HKAnchoredObjectQuery`) → `classifyArousal`. Needs HealthKit entitlement + permission. **This is the signal web can't get — the point of the iOS port.**
   - **Location**: `CLLocationManager` coarse (`reducedAccuracy`) → location hint.
   - All raw data stays on device; nothing is recorded or transmitted.
3. **Scoring.swift**: add `sensorBonus(seed, ctx)` — port the rules above exactly;
   call it in `scoreSeed` total. Keep the late-night safety gate untouched.
4. **Context build**: thread `activity/ambient/arousal` into the snapshot the
   recommender consumes (mirror `buildAmbientContext`).
5. **HomeView / AmbientField**: surface the sensed bits in the day-line
   (走着/在路上 · 周围很安静/周围有点热闹), like web `core 10`.
6. **Opt-in + automatic** (mirror the web fix): sensing is **both**:
   - **Automatic** where permission-free / already-granted: start motion on launch;
     auto-resume mic + HealthKit + location if the user previously enabled them
     (persist a `senseAround` flag in `UserDefaults`; permissions persist, so no
     re-prompt).
   - **Clickable**: a gentle `感受周围` control that requests the permissions and
     flips the flag on.

## Required Info.plist / entitlements
- `NSMicrophoneUsageDescription` ("感受周围的声音，帮我挑现在合适的事；只在本机，不录音。")
- `NSMotionUsageDescription`
- `NSLocationWhenInUseUsageDescription`
- HealthKit entitlement + `NSHealthShareUsageDescription` (read heart rate)
All copy in the tender voice; emphasize on-device + no recording.

## Privacy (non-negotiable — see CLAUDE.md / product-philosophy)
Only **coarse derived context** ever feeds the ranking. Raw audio, heart rate, and
precise location **never leave the device** and are not stored. Read level → derive
coarse signal → forget the raw.

## Acceptance
- `ios-glass` builds + runs (simulator for motion/mic; **a real device or simulated
  HealthKit data** for heart rate).
- `sensorBonus` matches the web rules (same inputs → same sign/order shifts).
- Sensing is automatic where it can be and clickable to opt in; day-line shows the
  sensed bits.
- Info.plist strings present; nothing transmitted.
- Commit on `ios-glass` with the `Co-Authored-By` trailer; push. Report what was
  verified in Xcode and anything a human must check on a real device (HR).
