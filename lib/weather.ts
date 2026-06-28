import type { Coords } from "@core/geo";

/**
 * Coarse weather via open-meteo (free, key-free, no token). Pure helpers; the
 * component does the opt-in fetch, only when a coarse location is already saved.
 * Weather just tints the scene a little — it never changes what's recommended.
 */

export type WeatherKind = "clear" | "clouds" | "rain" | "snow" | "fog" | "storm";

export function buildOpenMeteoUrl(c: Coords): string {
  return (
    "https://api.open-meteo.com/v1/forecast" +
    `?latitude=${c.lat}&longitude=${c.lng}&current_weather=true`
  );
}

/** Pull the current WMO weather code out of an open-meteo response. */
export function parseOpenMeteo(json: unknown): number | null {
  const code = (json as { current_weather?: { weathercode?: unknown } })?.current_weather?.weathercode;
  return typeof code === "number" ? code : null;
}

/** WMO weather code → a coarse kind. */
export function classifyWeather(code: number): WeatherKind {
  if (code === 0) return "clear";
  if (code === 45 || code === 48) return "fog";
  if (code >= 95) return "storm";
  if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "snow";
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return "rain";
  return "clouds"; // 1,2,3 and anything else mild
}

/** A soft tint veil for the scene, or null for clear (let the warmth show). */
export function weatherTint(kind: WeatherKind): string | null {
  switch (kind) {
    case "clear":
      return "radial-gradient(82% 60% at 50% 0%, rgba(255,226,158,0.18), transparent 70%)";
    case "clouds":
      return "linear-gradient(180deg, rgba(176,182,194,0.18), transparent 64%)";
    case "rain":
      return "linear-gradient(180deg, rgba(92,122,168,0.24), rgba(70,92,132,0.12))";
    case "snow":
      return "linear-gradient(180deg, rgba(226,233,243,0.32), transparent 72%)";
    case "fog":
      return "linear-gradient(180deg, rgba(200,202,206,0.32), rgba(200,202,206,0.14))";
    case "storm":
      return "linear-gradient(180deg, rgba(58,62,84,0.36), rgba(40,42,60,0.18))";
  }
}

export function weatherLabel(kind: WeatherKind): string {
  return { clear: "晴", clouds: "多云", rain: "雨", snow: "雪", fog: "雾", storm: "雷雨" }[kind];
}
