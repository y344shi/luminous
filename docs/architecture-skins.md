# Architecture — shared core + swappable skins

luminous used to live as parallel aesthetic branches (glass / sense / craft /
ocean). It now lives on **one trunk (`main`)**: the foundational core is written
**once** and shared, and each look is a thin, swappable **skin** chosen by config.
This is the same shape on web and iOS, so a feature added to the core reaches
every look for free.

## The split: core vs skin
**Core** — everything that decides *what* the app does and says. Pure, React-free
domain logic lives in `lib/` and is ported to iOS once:

> `types`, `scoring`, `seedParser`, `semanticTime`, `context`, `traceGenerator`,
> `store`, `geo`, `ambient`, `weather`, `places`, `dayGrade`, `feedback`,
> `keepsake`, `webpush`, `sceneBackground`, `bubblePhysics`.

The app shell (`app/`), the store/provider, and the shared home pieces under
`components/home/` (`SceneBackground`, `NavLayer`, `glyphs`, `GlassFilters`,
`SceneWindow`, `BubbleField`) are also core. Anything **two or more skins need**
belongs here, not inside a skin.

## Skin — only *how* the Home field looks and moves
Skins live in `components/home/skins/` and render the field over the shared scene
+ nav:

| skin  | component    | feel |
| ----- | ------------ | ---- |
| glass | `GlassField` | liquid-glass bubble field |
| ocean | `OceanField` | the same field with a `buoyancy` prop (floats/bobs) |
| paper | `PaperHome`  | warm paper / field-notebook, slow and tactile |

A skin is presentation only. It reads core state and emits the same events
(add / open / complete) — it must never fork domain logic. `OceanField` is
literally `<BubbleField buoyancy />`: a prop, not a fork, so the two can't drift.

## The switch
`lib/aesthetic.ts` exposes the active skin, defaulting to glass:

```ts
export type Aesthetic = "glass" | "ocean" | "paper";
export const AESTHETIC =
  (process.env.NEXT_PUBLIC_AESTHETIC as Aesthetic) ?? "glass";
```

`app/page.tsx` reads `AESTHETIC` and renders the matching skin. Selecting a look
is just an env var — no branch, no code change:

```bash
NEXT_PUBLIC_AESTHETIC=ocean npm run dev
NEXT_PUBLIC_AESTHETIC=paper npm run build
```

`scripts/shoot-home.sh <skin>` honors the same env var, so per-skin screenshots
are `bash scripts/shoot-home.sh <glass|ocean|paper>`.

## Adding a new skin
1. Create `components/home/skins/<Name>.tsx`. Compose the shared pieces
   (`SceneBackground`, `NavLayer`, `SceneWindow`, `GlassFilters`, `BubbleField`);
   read core state via the store; emit the standard events. No new domain logic.
2. Add its key to the `Aesthetic` union in `lib/aesthetic.ts` and wire it into the
   switch in `app/page.tsx`.
3. Keep it green: `npm run typecheck && npm test && npm run build`.
4. Capture it: `bash scripts/shoot-home.sh <skin>` → `docs/shots/<skin>.png`.
5. If the new look needs a shared capability, add it to `lib/` or the shared home
   pieces — never bury it in the skin.

## iOS mirrors this
The native app uses the same shape: the ported `lib/` core (Swift) is shared, and
an `Aesthetic` enum plus a `RootView`/`HomeView` switch select the SwiftUI skin
(`GlassField.swift`, `OceanField.swift` = `GlassField(buoyancy: true)`,
`PaperField.swift`). The enum case names track the web `Aesthetic` union, so the
two platforms stay in step: add a case, add a skin view, switch on it. Core
changes are ported once and inherited by every skin on both platforms.
