import { describe, it, expect } from "vitest";
import { step, collide, gravityFromOrientation, type Body } from "@core/bubblePhysics";

function body(over: Partial<Body> = {}): Body {
  return { id: "b", x: 100, y: 100, vx: 0, vy: 0, r: 20, m: 1, ...over };
}

describe("bubblePhysics — gravity from orientation", () => {
  it("flat device → ~no gravity", () => {
    expect(gravityFromOrientation(0, 0)).toEqual({ gx: 0, gy: 0 });
  });
  it("tilt right/forward pushes gravity that way; clamps at 90°", () => {
    const g = gravityFromOrientation(90, 45, 900);
    expect(g.gx).toBe(900);
    expect(g.gy).toBeCloseTo(450, 0);
    expect(gravityFromOrientation(200, -200, 900)).toEqual({ gx: 900, gy: -900 });
  });
  it("null orientation is treated as flat", () => {
    expect(gravityFromOrientation(null, null)).toEqual({ gx: 0, gy: 0 });
  });
});

describe("bubblePhysics — integration + walls", () => {
  it("gravity moves a body and damping bounds it", () => {
    const b = body({ x: 200, y: 50, vx: 0, vy: 0 });
    for (let i = 0; i < 10; i++) step([b], { w: 400, h: 400, gx: 0, gy: 900, dt: 1 / 60 });
    expect(b.y).toBeGreaterThan(50); // fell downward
    expect(b.y).toBeLessThanOrEqual(400 - b.r + 0.001); // stayed in bounds
  });
  it("bounces off the floor without escaping", () => {
    const b = body({ x: 200, y: 380, vy: 500 });
    step([b], { w: 400, h: 400, gx: 0, gy: 0, dt: 1 / 30, restitution: 0.6 });
    expect(b.y).toBeLessThanOrEqual(400 - b.r + 0.001);
    expect(b.vy).toBeLessThan(0); // velocity reversed upward
  });
});

describe("bubblePhysics — collisions", () => {
  it("separates two overlapping bodies", () => {
    const a = body({ id: "a", x: 100, y: 100 });
    const b = body({ id: "b", x: 120, y: 100 }); // overlap (d=20 < 40)
    collide(a, b, 0.7);
    const dist = Math.hypot(b.x - a.x, b.y - a.y);
    expect(dist).toBeGreaterThanOrEqual(a.r + b.r - 0.001);
  });
  it("step resolves a cluster so none stay overlapping", () => {
    const bodies = [
      body({ id: "a", x: 200, y: 200 }),
      body({ id: "b", x: 210, y: 205 }),
      body({ id: "c", x: 195, y: 210 }),
    ];
    for (let i = 0; i < 30; i++) step(bodies, { w: 600, h: 600, gx: 0, gy: 0, dt: 1 / 60 });
    for (let i = 0; i < bodies.length; i++)
      for (let j = i + 1; j < bodies.length; j++) {
        const d = Math.hypot(bodies[j].x - bodies[i].x, bodies[j].y - bodies[i].y);
        expect(d).toBeGreaterThan(bodies[i].r + bodies[j].r - 2);
      }
  });
  it("bodies bounce off the central anchor (orb)", () => {
    const b = body({ x: 300, y: 300, vx: -200, vy: 0, r: 16 });
    // anchor centered to the left so the body is overlapping it
    step([b], { w: 600, h: 600, gx: 0, gy: 0, dt: 1 / 60, anchor: { x: 290, y: 300, r: 60 } });
    const d = Math.hypot(b.x - 290, b.y - 300);
    expect(d).toBeGreaterThanOrEqual(60 + b.r - 1); // pushed outside the orb
  });
});
