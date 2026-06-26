import { bearingDeg, haversineMeters, distanceLabel, type Coords } from "./geo";

/**
 * Nearby places via OpenStreetMap Overpass (free, key-free). Pure helpers here
 * (query build + parse + nearest); the component does the opt-in fetch. Only the
 * coarse current location is sent to Overpass; nothing is stored or tracked.
 */

export type Place = { name: string; lat: number; lng: number; brand?: string };
export type NearPlace = Place & { distM: number; bearing: number; distLabel: string };

/** Overpass QL: cafés + Starbucks within `radiusM` of the point. */
export function buildOverpassQuery(c: Coords, radiusM = 1500): string {
  const a = `(around:${radiusM},${c.lat},${c.lng})`;
  return (
    "[out:json][timeout:12];" +
    `(node["amenity"="cafe"]${a};node["brand"="Starbucks"]${a};node["amenity"="coffee_shop"]${a};);` +
    "out 50;"
  );
}

/** Parse an Overpass JSON response into Places. */
export function parseOverpass(json: unknown): Place[] {
  const els = (json as { elements?: unknown })?.elements;
  if (!Array.isArray(els)) return [];
  const out: Place[] = [];
  for (const e of els) {
    const el = e as { lat?: unknown; lon?: unknown; tags?: Record<string, string> };
    if (typeof el.lat !== "number" || typeof el.lon !== "number") continue;
    const tags = el.tags ?? {};
    out.push({
      name: tags.name || tags.brand || "咖啡馆",
      lat: el.lat,
      lng: el.lon,
      brand: tags.brand,
    });
  }
  return out;
}

/** The nearest place (optionally preferring a brand, e.g. "Starbucks") with its
 * true bearing + distance from `from`. */
export function nearestPlace(
  from: Coords,
  places: Place[],
  preferBrand?: string
): NearPlace | null {
  if (!places.length) return null;
  let pool = places;
  if (preferBrand) {
    const branded = places.filter((p) =>
      (p.brand ?? p.name).toLowerCase().includes(preferBrand.toLowerCase())
    );
    if (branded.length) pool = branded;
  }
  let best: Place | null = null;
  let bestD = Infinity;
  for (const p of pool) {
    const d = haversineMeters(from, { lat: p.lat, lng: p.lng });
    if (d < bestD) {
      bestD = d;
      best = p;
    }
  }
  if (!best) return null;
  return {
    ...best,
    distM: bestD,
    bearing: bearingDeg(from, { lat: best.lat, lng: best.lng }),
    distLabel: distanceLabel(bestD),
  };
}

/** A coarse compass label for a bearing (for a north-up arrow caption). */
export function compassLabel(bearing: number): string {
  const dirs = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"];
  return dirs[Math.round(bearing / 45) % 8];
}
