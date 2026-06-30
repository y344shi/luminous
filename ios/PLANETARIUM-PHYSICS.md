# Planetarium Home — physics-grounded aesthetics spec

The glass Home is a small, scientifically-honest celestial scene. Every element is
tied to real physics. This is the reference; the render must satisfy the **Notice**
checklists. (Stylized for calm + readability, but never *wrong*.)

---

## 1. Black hole (center) — a Gargantua-class hole with a thin accretion disk
Real physics:
- **Event-horizon shadow:** the dark silhouette. Its apparent radius is ~**2.6 R_s**
  (photon-capture radius), larger than the horizon itself due to lensing.
- **Photon ring:** a thin, bright ring at the shadow edge — light that orbited the
  hole one+ times before escaping. Very thin, very bright.
- **Accretion disk:** plasma on Keplerian orbits. Seen near edge-on it's a thin
  ellipse — but **gravitational lensing bends the far side's light up and over the
  top, and under the bottom**, so the far side appears as an arc wrapping the shadow
  (the "halo"). The **near side passes in front** of the lower hemisphere.
- **Doppler beaming + relativistic boosting:** the side rotating **toward** the
  viewer is dramatically **brighter (and blueshifted)**; the receding side is dimmer
  (and redshifted). → strong **left–right brightness asymmetry**.
- **Temperature gradient:** inner disk hotter → **blue-white**; outer → **orange-red**.
  Gravitational redshift reddens light nearest the hole.

**Notice (must be true):**
- [ ] Shadow is truly black, circular, ~2.6 R_s; not a grey disc.
- [ ] Thin bright **photon ring** hugs the shadow.
- [ ] Far side of the disk **arcs over the top** of the shadow (lensing); near side
      crosses **in front** of the bottom.
- [ ] **One side is much brighter** than the other (Doppler) — and the bright side
      is on the side the disk rotates **toward** the viewer (must match orbit sense, §2).
- [ ] Disk color runs **blue-white (inner) → orange (outer)**.

## 2. Orbits (the wishes) — Keplerian
Real physics (Kepler / Newton):
- **1st law:** orbits are ellipses with the mass at a focus.
- **2nd law:** equal areas in equal time → faster at perihelion (nearest), slower at
  aphelion.
- **3rd law:** **T ∝ a^{3/2}** → inner wishes orbit **faster**, outer **slower** (not
  linearly — by the 3/2 power).
- All bodies orbit the **same sense** (prograde), **co-planar** with the disk → the
  orbit ellipses share the disk's inclination (same vertical squash).

**Notice:**
- [ ] Inner orbit is clearly **faster** than outer, scaling ~a^{3/2} (not constant, not linear).
- [ ] **All wishes orbit the same direction**, and that direction matches the disk's
      Doppler bright side (§1).
- [ ] Orbit ellipses share the **disk's inclination** (same y-squash) — they look like
      they lie in one plane, not random tilts.
- [ ] A wish **never overlaps the shadow**; closest orbit clears the photon ring.

## 3. Tilt = gravity (the "pull star")
- Device tilt defines a real **down**. We treat it as an extra gravitational source:
  the whole system is **pulled toward the tilt's low side**.
- A true sim integrates this as an external acceleration (orbits drift/precess toward
  it). The current build approximates it as a displacement ∝ tilt, **stronger on
  outer orbits** (weaker binding ⇒ more perturbed) — physically the right sign.

**Notice:**
- [ ] Tilting pulls planets toward the **physical down** of the tilt.
- [ ] **Outer planets move more** under tilt than inner (looser binding).
- [ ] (Goal) true velocity integration so orbits *precess*, not just shift.

## 4. Shooting stars (the suggestions) — meteors
Real physics:
- A meteor is a fast body on a near-straight path; its **train (tail) trails directly
  anti-parallel to the velocity** — i.e., **behind** the head, never sideways.
- The **head is brightest**; the tail fades to nothing **backward** along the path.
- Brief: it brightens, streaks, fades.

**Notice (the bug you caught):**
- [ ] Tail is **exactly anti-parallel to travel** (head leads, tail behind) — at all
      angles, not a fixed rotation.
- [ ] Tail **fades from bright (at head) → transparent (away)**.
- [ ] Head brightest; path straight; whole thing fades in and out.

## 5. Background sky
- Stars are far → **near-fixed** (parallax negligible) with faint **twinkle**.
- Notice: [ ] stars don't swim with motion; subtle twinkle only.

---

## Design decisions (stylized-but-honest)
- **Inclination:** a true edge-on disk would line wishes up unreadably. We pick a
  single shared inclination (~35°, y-squash ≈ 0.6–0.7) for **both** the disk and the
  orbit ellipses, so they're coherent and the wishes stay legible.
- **Time compression:** real orbital periods are irrelevant; we keep Kepler's *ratios*
  (a^{3/2}) but choose an inner period that reads as calm (~60–90 s).
- **Color/temperature** is suggested, not spectrally exact.
- **Convention:** disk rotates so its **left** side approaches the viewer ⇒ left is the
  bright (Doppler) side ⇒ orbits run the matching sense.

## Real integrator (shipped — `OrbitSim.swift`)
The orbits are no longer kinematic. Each wish is a body integrated with
**velocity-Verlet** every frame from `TimelineView`:
- **Central field** `a = −μ·r̂ / r²`, softened (`+soft²` in the denominator) so a
  perturbed orbit can't blow up diving at the hole. μ is solved from a reference
  ring/period (r₀ = 136 pt, T₀ = 70 s), so circular orbits reproduce the old feel
  **and** Kepler's 3rd law (`T ∝ r^{3/2}`) falls out for free — inner orbits faster.
- **Tilt** is a *uniform* acceleration field = device-lean × `tiltScale`, capped at
  ~40 % of the central pull at r₀. A uniform field on a bound orbit shifts the focus
  and makes the ellipse **precess** rather than just displacing it — so leaning the
  phone slowly rotates the whole orbit, it doesn't snap.
- The upright baseline (`g.height ≈ −1` held vertically) is removed by the caller, so
  only a genuine lean perturbs anything.
- 4 sub-steps/frame for stability; gaps > 0.5 s (app resume) are skipped, not integrated.
- The sim is a plain (non-`@Observable`) object in `@State`: stepped and read each
  frame, so it never invalidates the view graph (no feedback loop).
- **Note:** the Simulator has no motion sensors → tilt = 0 there, so you see clean
  Keplerian circles. Precession is only visible on a physical device.

## Open / next
- Drag-to-throw: let a dragged planet hand its release velocity to the sim (currently
  drag is a spring-back visual offset on top of the simulated position).
- Per-skin: the black hole suits **glass**; ocean/paper should keep their own centers.
