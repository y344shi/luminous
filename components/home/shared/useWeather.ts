import { useEffect, useState } from "react";
import type { Coords } from "@core/geo";
import { buildOpenMeteoUrl, parseOpenMeteo, classifyWeather, type WeatherKind } from "@core/weather";

/**
 * Coarse current weather for a *saved, coarse* location (open-meteo, key-free). Only
 * the already-coarsened home coords leave the device, and only to fetch weather — it
 * gently informs the ranking (good outdoor weather lifts "step outside" wishes), never
 * forces it. No coords, no fetch.
 */
export function useWeather(coords: Coords | null | undefined): WeatherKind | undefined {
  const [kind, setKind] = useState<WeatherKind | undefined>(undefined);
  useEffect(() => {
    if (!coords) return;
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch(buildOpenMeteoUrl(coords));
        if (!res.ok) return;
        const code = parseOpenMeteo(await res.json());
        if (code != null && !cancelled) setKind(classifyWeather(code));
      } catch {
        /* offline / blocked — simply no weather signal */
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [coords?.lat, coords?.lng]);
  return kind;
}

/** Good weather to be outside in: clear or mild cloud. */
export function isGoodOutdoorWeather(kind: WeatherKind | undefined): boolean | undefined {
  if (kind == null) return undefined;
  return kind === "clear" || kind === "clouds";
}
