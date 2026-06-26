import { describe, it, expect } from "vitest";
import {
  buildOverpassQuery,
  parseOverpass,
  nearestPlace,
  compassLabel,
} from "@/lib/places";

const here = { lat: 45.5017, lng: -73.5673 };

describe("places — overpass query", () => {
  it("builds a key-free Overpass query around the point", () => {
    const q = buildOverpassQuery(here, 1200);
    expect(q).toContain("[out:json]");
    expect(q).toContain("around:1200,45.5017,-73.5673");
    expect(q).toContain('"amenity"="cafe"');
    expect(q).toContain('"brand"="Starbucks"');
  });
});

describe("places — parse + nearest", () => {
  const json = {
    elements: [
      { lat: 45.5025, lon: -73.5673, tags: { name: "Far Café" } }, // ~89m N
      { lat: 45.5018, lon: -73.5673, tags: { name: "Starbucks", brand: "Starbucks" } }, // ~11m N
      { type: "way" }, // ignored (no lat/lon)
    ],
  };

  it("parses café nodes, ignoring non-nodes", () => {
    const places = parseOverpass(json);
    expect(places.length).toBe(2);
    expect(places.map((p) => p.name)).toContain("Starbucks");
  });

  it("returns [] for a malformed response", () => {
    expect(parseOverpass({})).toEqual([]);
    expect(parseOverpass(null)).toEqual([]);
  });

  it("nearest prefers the brand and gives bearing + distance", () => {
    const n = nearestPlace(here, parseOverpass(json), "Starbucks")!;
    expect(n.name).toBe("Starbucks");
    expect(n.distM).toBeLessThan(40); // the very close one
    expect(n.bearing).toBeGreaterThanOrEqual(0);
    expect(n.distLabel).toMatch(/m|km/);
  });

  it("compassLabel maps a bearing to a direction", () => {
    expect(compassLabel(0)).toBe("北");
    expect(compassLabel(90)).toBe("东");
    expect(compassLabel(180)).toBe("南");
    expect(compassLabel(270)).toBe("西");
  });
});
