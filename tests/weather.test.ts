import { describe, it, expect } from "vitest";
import {
  buildOpenMeteoUrl,
  parseOpenMeteo,
  classifyWeather,
  weatherTint,
  weatherLabel,
} from "@core/weather";

describe("weather", () => {
  it("builds a key-free open-meteo url", () => {
    const u = buildOpenMeteoUrl({ lat: 45.5, lng: -73.6 });
    expect(u).toContain("api.open-meteo.com");
    expect(u).toContain("latitude=45.5");
    expect(u).toContain("longitude=-73.6");
    expect(u).toContain("current_weather=true");
    expect(u).not.toMatch(/key|token|apikey/i);
  });

  it("parses the current weather code, or null when absent", () => {
    expect(parseOpenMeteo({ current_weather: { weathercode: 61 } })).toBe(61);
    expect(parseOpenMeteo({})).toBeNull();
    expect(parseOpenMeteo(null)).toBeNull();
  });

  it("classifies WMO codes into coarse kinds", () => {
    expect(classifyWeather(0)).toBe("clear");
    expect(classifyWeather(2)).toBe("clouds");
    expect(classifyWeather(48)).toBe("fog");
    expect(classifyWeather(63)).toBe("rain");
    expect(classifyWeather(81)).toBe("rain");
    expect(classifyWeather(73)).toBe("snow");
    expect(classifyWeather(96)).toBe("storm");
  });

  it("tints every kind except gives clear a warm glow; labels are zh", () => {
    for (const k of ["clear", "clouds", "rain", "snow", "fog", "storm"] as const) {
      expect(typeof weatherTint(k)).toBe("string");
      expect(weatherLabel(k).length).toBeGreaterThan(0);
    }
    expect(weatherTint("rain")).toContain("gradient");
  });
});
