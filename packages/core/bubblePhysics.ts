/**
 * A tiny soft-physics engine for the dreamy bubble field. Pure + deterministic
 * (no time/RNG inside) so it can be unit-tested; the component drives it with a
 * rAF loop and feeds gravity from the device gyroscope. Bodies are circles in
 * pixel space. n is small (≲ 20), so O(n²) collisions are fine.
 */

export type Body = {
  id: string;
  x: number;
  y: number;
  vx: number;
  vy: number;
  r: number;
  m: number;
};

export type StepEnv = {
  w: number;
  h: number;
  gx: number; // gravity px/s²
  gy: number;
  dt: number; // seconds
  damping?: number; // velocity retention per step (0..1)
  restitution?: number; // bounciness (0..1)
  /** A fixed central body bubbles bounce off (the orb). */
  anchor?: { x: number; y: number; r: number };
  /** Gentle pull of each body toward a point (calm clustering). */
  pull?: { x: number; y: number; k: number };
};

/** Map device orientation (gamma left-right, beta front-back, degrees) to a
 * gravity vector. Tilting the phone makes bubbles slide that way. */
export function gravityFromOrientation(
  gamma: number | null,
  beta: number | null,
  scale = 900
): { gx: number; gy: number } {
  const g = clampDeg(gamma ?? 0);
  const b = clampDeg(beta ?? 0);
  return { gx: (g / 90) * scale, gy: (b / 90) * scale };
}

function clampDeg(d: number): number {
  if (d > 90) return 90;
  if (d < -90) return -90;
  return d;
}

/** Resolve a circle-circle overlap + exchange velocity along the normal. */
export function collide(a: Body, b: Body, restitution: number): void {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const d = Math.hypot(dx, dy) || 0.0001;
  const overlap = a.r + b.r - d;
  if (overlap <= 0) return;
  const nx = dx / d;
  const ny = dy / d;
  const totalM = a.m + b.m;
  // positional correction split by mass
  a.x -= nx * overlap * (b.m / totalM);
  a.y -= ny * overlap * (b.m / totalM);
  b.x += nx * overlap * (a.m / totalM);
  b.y += ny * overlap * (a.m / totalM);
  // impulse
  const rvn = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
  if (rvn > 0) return; // already separating
  const j = (-(1 + restitution) * rvn) / (1 / a.m + 1 / b.m);
  a.vx -= (j * nx) / a.m;
  a.vy -= (j * ny) / a.m;
  b.vx += (j * nx) / b.m;
  b.vy += (j * ny) / b.m;
}

/** Bounce a body off the immovable anchor (the central orb). */
function collideAnchor(body: Body, ax: number, ay: number, ar: number, restitution: number): void {
  const dx = body.x - ax;
  const dy = body.y - ay;
  const d = Math.hypot(dx, dy) || 0.0001;
  const overlap = body.r + ar - d;
  if (overlap <= 0) return;
  const nx = dx / d;
  const ny = dy / d;
  body.x += nx * overlap;
  body.y += ny * overlap;
  const vn = body.vx * nx + body.vy * ny;
  if (vn < 0) {
    body.vx -= (1 + restitution) * vn * nx;
    body.vy -= (1 + restitution) * vn * ny;
  }
}

/** Advance all bodies one step (mutates in place). */
export function step(bodies: Body[], env: StepEnv): void {
  const damping = env.damping ?? 0.985;
  const restitution = env.restitution ?? 0.7;
  const { w, h, gx, gy, dt } = env;

  for (const p of bodies) {
    p.vx += gx * dt;
    p.vy += gy * dt;
    if (env.pull) {
      p.vx += (env.pull.x - p.x) * env.pull.k * dt;
      p.vy += (env.pull.y - p.y) * env.pull.k * dt;
    }
    p.vx *= damping;
    p.vy *= damping;
    p.x += p.vx * dt;
    p.y += p.vy * dt;

    // walls
    if (p.x < p.r) { p.x = p.r; p.vx = Math.abs(p.vx) * restitution; }
    else if (p.x > w - p.r) { p.x = w - p.r; p.vx = -Math.abs(p.vx) * restitution; }
    if (p.y < p.r) { p.y = p.r; p.vy = Math.abs(p.vy) * restitution; }
    else if (p.y > h - p.r) { p.y = h - p.r; p.vy = -Math.abs(p.vy) * restitution; }

    if (env.anchor) collideAnchor(p, env.anchor.x, env.anchor.y, env.anchor.r, restitution);
  }

  for (let i = 0; i < bodies.length; i++) {
    for (let j = i + 1; j < bodies.length; j++) {
      collide(bodies[i], bodies[j], restitution);
    }
  }
}
