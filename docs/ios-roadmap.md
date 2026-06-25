# iOS Roadmap

Order: **Web MVP → PWA → iOS native.** Do not start iOS before the web MVP feels right.

## Web MVP (done in Cycle 1)
Next.js, mobile-first, localStorage, rule scoring, mock parser.

## PWA (next)
- `manifest.webmanifest`, icons, theme-color, `viewport-fit=cover` (already set), safe-area padding (already in shell/nav).
- Service worker for offline shell + add-to-home-screen.
- Basic local notifications (gentle, respects quiet hours + max reminders/day).

## iOS native (later, Expo / React Native)
Shared packages to extract first:
- `packages/core` ← lift `lib/{types,scoring,semanticTime,context,seedParser,traceGenerator,mockSeeds}.ts` (already React-free).
- `packages/design` ← `themes.ts`, spacing/radius/shadow, `copy.ts`.

iOS-specific later: native push, Home/Lock-screen widgets ("today's trace"), HealthKit (coarse energy only), Calendar (free-gap detection), Siri shortcut ("现在别消失"), Apple Watch complication.

## Privacy carried into native
Send only coarse context to any AI ("near outdoor", "low energy", "15 min", "weather good") — never GPS or biometrics.
