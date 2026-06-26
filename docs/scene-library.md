# Scene Library — 100 scenarios + graphics sources

The background reflects the sensed state. `ambient.orbScene` maps to a small set
of keys today; this is the full target vocabulary and where to source beautiful,
**transparent / high-res / 3D** assets for each. Privacy: only coarse signals
drive the scene; nothing is tracked.

## Graphics & 3D resource libraries (free, license-noted)
**Use these instead of system emoji / dated clip-art.**
- **Lucide** (MIT) — line icons. *In use* for glyphs. Phosphor (MIT, duotone), Tabler (MIT) are alternates.
- **Iconify** — aggregator of 200k+ open icons (one API), transparent SVG.
- **OpenMoji** (CC BY-SA) — open-source emoji as clean transparent SVG (a consistent, modern emoji set).
- **unDraw** (MIT-ish, free) — recolorable flat illustrations (desk, coffee, travel…). **Open Doodles**, **Humaaans**, **Open Peeps** (CC0) — illustration kits.
- **Lottiefiles** — animated, transparent JSON (great for a living orb / scene). Render with `lottie-react`.
- **Poly Haven** (CC0) — HDRIs, textures, **3D models**; free API, no key. Best for real 3D + lighting.
- **Spline** — design + embed 3D scenes (iframe/`@splinetool/react-spline`); free tier. **three.js** + **@react-three/drei** for custom 3D.
- **Unsplash** / **Pexels** — high-res CC0-ish photos (API key) for wallpaper-grade backgrounds; curate per scene. **Picsum** for key-free placeholders.
- **SVG Repo** — large free SVG bank (mixed licenses — check per asset).

**Recommended path:** keep the gradient base (always works) → layer a curated
**Unsplash/Pexels** photo per scene (env-keyed) → for the top scenes, a **Spline /
three.js** 3D or a **Lottie** loop. All under a theme scrim for legibility.

## The 100 scenarios (scene key · search terms)
### Home & indoor (1–12)
home · bedroom-bed · sofa-livingroom · desk-by-window · kitchen-morning ·
bathroom-mirror · balcony-plants · reading-nook · fireplace · dining-table ·
window-rain · home-office

### Work & study (13–24)
office-desk · open-office · meeting-room · library · study-hall · lab-bench ·
coworking · whiteboard · classroom · campus-quad · lecture-hall · cubicle

### Food & drink (25–37)
coffee-shop · starbucks-window · tea-house · bakery · brunch-cafe · bar-evening ·
ramen-counter · street-food · ice-cream · juice-bar · pizzeria · diner · picnic

### Transit & road (38–50)
highway-dusk · city-bus · subway-platform · train-window · car-interior ·
bike-lane · airport-gate · ferry-deck · taxi-night · parking-garage ·
crosswalk · gas-station · road-trip

### Nature & outdoor (51–66)
grass-field · meadow-flowers · forest-trail · mountain-peak · lakeside ·
riverbank · beach-shore · desert-dunes · countryside-yard · orchard ·
waterfall · hill-sunset · pine-woods · bamboo-grove · rice-terrace · canyon

### Urban (67–78)
downtown-street · skyline-night · rooftop · alley-lanterns · plaza-fountain ·
market-stalls · museum-hall · bookstore · gallery · pier-boardwalk ·
neon-district · old-town

### Wellness & body (79–88)
gym · yoga-studio · pool · running-track · spa · garden-zen · sauna ·
climbing-wall · stretching-mat · morning-walk

### Sky, time & weather (89–100)
dawn · golden-hour · blue-hour · starry-night · full-moon · overcast ·
rainy-window · snowfall · foggy-morning · thunderstorm · clear-noon · aurora

## How a scene is chosen
Coarse location (`guessLocation` / opt-in geo) + time-of-day + (later) weather +
nearby-places (Overpass) → a scene key → `sceneVisual` (gradient) and, when
available, a curated image / 3D. See `docs/overnight-plan.md` direction **B**.
