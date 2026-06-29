# luminous — Integration Guide

How the pieces fit together, and how to integrate the **next platform** (React
Native / iOS) on top of the shared core. Companion to `docs/CONTEXT.md` (status) and
`docs/ios-sensor-port.md` (the native sensing brief). Current as of `core 42`.

## The shape
```
packages/core  →  @luminous/core   the framework-free brain (no React/Next/browser)
lib/           →  the platform boundary (Zustand store, localStorage, browser/UI helpers)
components/    →  the web UI (skins + shared field + sensing hooks)
app/           →  Next.js routes
```
- **Web** consumes the core via the `@core/*` tsconfig+vitest alias (no build step).
- **Native** (future) consumes it as a real dependency: `@luminous/core` has a
  `package.json` with a subpath `exports` map (`@luminous/core/scoring`, etc.).
- Two guards keep the boundary honest (`tests/corePurity.test.ts`): core imports **no**
  React/Next/Zustand, and core imports **nothing from the app** (`@/…` / `../`).

## The integration contract — what `@luminous/core` exposes
The whole life-loop + ranking is pure and importable:
- **Recommend**: `recommend(seeds, ctx, {rng,limit})` / `rankSeeds(...)` → opportunities.
  `scoreSeed` composes fits + mood + `triggerBonus` + `sensorBonus` + `dwellBonus` +
  `batteryBonus`, with the **late-night safety gate**. (`@core/scoring`)
- **Context**: `buildContext(...)` (stated) / `buildAmbientContext(...)` (sensed) →
  `ContextSnapshot`. (`@core/context`, `@core/ambient`)
- **Classifiers** (the on-device senses): `classifyActivity` / `classifyAmbient` /
  `classifyArousal` (`@core/sensors`), `dwellLevel`/`advanceDwell` (`@core/dwell`),
  `classifyWeather`/`isGoodOutdoorWeather`-inputs (`@core/weather`), `isBatteryLow`
  (`@core/battery`).
- **Domain**: `@core/types`, `@core/seedParser` (+ `@core/aiParser`), `@core/traceGenerator`,
  `@core/mockSeeds`, `@core/illustration` (`illustrationCategory`), `@core/semanticTime`,
  `@core/categoryMeta`, `@core/copy`, `@core/reminders`, `@core/bubblePhysics`.

## The pattern that makes it portable: pure classifier + platform sampler
A sense = **pure classifier (shared)** + **platform sampler (per platform)**.
- Web samplers are React hooks, bundled by one façade `useSensedSignals()`
  (`components/home/shared/`): `useSensors` (DeviceMotion + mic), `useDwell`
  (localStorage), `useWeather` (open-meteo for a saved home), `useBattery`.
  Each feeds the **same** `@core` classifier and degrades to `undefined` when absent.
- **To integrate native:** write the samplers with native APIs, feed the identical
  classifiers, build a `ContextSnapshot`, call `recommend`. **No ranking is re-written.**

| signal | classifier (shared) | web sampler | native sampler |
| --- | --- | --- | --- |
| motion | `classifyActivity` | DeviceMotion | CoreMotion / expo-sensors |
| loudness | `classifyAmbient` | getUserMedia + AudioContext | AVAudioEngine / expo-av |
| heart rate→arousal | `classifyArousal` | — (web can't) | **HealthKit** |
| dwell | `dwellLevel`/`advanceDwell` | localStorage | UserDefaults / AsyncStorage |
| weather | `classifyWeather` | open-meteo fetch | open-meteo fetch |
| battery | `isBatteryLow` | Battery API | UIDevice / expo-battery |
| location/time | (in `ambient`/`semanticTime`) | geo + clock | CoreLocation + clock |

## State & persistence boundary (stays per-platform)
`lib/store.ts` (Zustand) and `lib/storage.ts` (localStorage) are **not** in core — they're
the app's state/persistence. A native app brings its own store + persistence adapter and
calls the same `@core` functions. (Illustration *packs* are React/SVG and live in
`components/home/shared/illustrationPacks.tsx`, not core — native renders its own art behind
the same `IllustrationArt({style, category})` contract.)

## Integrating a React Native / Expo app
1. Make the repo an npm workspace (or pnpm); add `@luminous/core` as a workspace dep.
2. RN/Metro: ensure `@luminous/core` is transpiled (Metro resolves TS via config; Next
   would use `transpilePackages`). The web app needs **no change** (it uses the alias).
3. Implement the platform samplers (table above) → `buildAmbientContext(...)` →
   `recommend(...)`. Reuse `seedParser`, `traceGenerator`, `copy` verbatim.
4. Bring a native store + persistence; render skins with Skia/Reanimated/svg.
5. HealthKit unlocks **arousal**, the one signal web can't read.

## Privacy contract (non-negotiable — see CLAUDE.md / product-philosophy)
Only **coarse derived context** ever feeds the ranking. Raw audio, heart rate, and
precise location **never leave the device** and are not stored: read level → derive a
coarse signal → forget the raw. (Weather sends only an already-coarsened home coordinate
to open-meteo.)

## Verify
`npm run typecheck && npm test && npm run build` — TS clean, **296 tests** green, all
three skins build. `npm run dev:https` to exercise the mic/motion senses on a phone.
