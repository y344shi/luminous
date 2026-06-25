/**
 * Tiny geo helpers for the "sense home" feature. Privacy-first: coordinates are
 * rounded coarse (~100m) before they're ever stored, and they never leave the
 * device — they're only compared locally to decide "at home / away / moving".
 */

export type Coords = { lat: number; lng: number };

/** Round to ~3 decimals (~110m) so we never keep a precise location. */
export function roundCoarse(c: Coords, decimals = 3): Coords {
  const p = 10 ** decimals;
  return { lat: Math.round(c.lat * p) / p, lng: Math.round(c.lng * p) / p };
}

/** Great-circle distance in metres between two coarse points. */
export function haversineMeters(a: Coords, b: Coords): number {
  const R = 6_371_000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const la1 = toRad(a.lat);
  const la2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(la1) * Math.cos(la2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** Within `radiusM` of a saved home? Null inputs → not-at-home (unknown). */
export function isAtHome(
  home: Coords | null,
  current: Coords | null,
  radiusM = 200
): boolean {
  if (!home || !current) return false;
  return haversineMeters(home, current) <= radiusM;
}

/** A geolocation speed (m/s) above a walking pace reads as "on the move". */
export function isMovingSpeed(speed: number | null | undefined, thresholdMs = 1.2): boolean {
  return speed != null && speed > thresholdMs;
}
