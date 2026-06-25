import { describe, it, expect } from "vitest";
import { roundCoarse, haversineMeters, isAtHome, isMovingSpeed } from "@/lib/geo";

const home = { lat: 45.5017, lng: -73.5673 }; // Montreal-ish

describe("geo — privacy + distance", () => {
  it("rounds coordinates coarse (~100m) before storing", () => {
    const r = roundCoarse({ lat: 45.50171234, lng: -73.56731234 });
    expect(r).toEqual({ lat: 45.502, lng: -73.567 });
  });

  it("haversine ~0 for the same point and grows with distance", () => {
    expect(haversineMeters(home, home)).toBeLessThan(1);
    const near = { lat: home.lat + 0.001, lng: home.lng }; // ~111m north
    const d = haversineMeters(home, near);
    expect(d).toBeGreaterThan(90);
    expect(d).toBeLessThan(130);
  });

  it("isAtHome true within radius, false outside, false on null", () => {
    expect(isAtHome(home, { lat: home.lat + 0.001, lng: home.lng }, 200)).toBe(true);
    expect(isAtHome(home, { lat: home.lat + 0.01, lng: home.lng }, 200)).toBe(false); // ~1.1km
    expect(isAtHome(null, home)).toBe(false);
    expect(isAtHome(home, null)).toBe(false);
  });

  it("isMovingSpeed treats walking pace as moving, null as not", () => {
    expect(isMovingSpeed(2.0)).toBe(true);
    expect(isMovingSpeed(0.3)).toBe(false);
    expect(isMovingSpeed(null)).toBe(false);
    expect(isMovingSpeed(undefined)).toBe(false);
  });
});
