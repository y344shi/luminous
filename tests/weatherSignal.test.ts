import { describe, it, expect } from "vitest";
import { isGoodOutdoorWeather } from "@/components/home/shared/useWeather";

describe("isGoodOutdoorWeather", () => {
  it("clear + mild cloud are good; wet/harsh are not; unknown stays undefined", () => {
    expect(isGoodOutdoorWeather("clear")).toBe(true);
    expect(isGoodOutdoorWeather("clouds")).toBe(true);
    expect(isGoodOutdoorWeather("rain")).toBe(false);
    expect(isGoodOutdoorWeather("snow")).toBe(false);
    expect(isGoodOutdoorWeather("fog")).toBe(false);
    expect(isGoodOutdoorWeather("storm")).toBe(false);
    expect(isGoodOutdoorWeather(undefined)).toBeUndefined();
  });
});
