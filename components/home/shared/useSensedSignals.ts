import { useStore } from "@/lib/store";
import { useSensors } from "./useSensors";
import { useDwell } from "./useDwell";
import { useWeather, isGoodOutdoorWeather } from "./useWeather";
import { useBattery } from "./useBattery";
import type { Activity, Ambient } from "@core/sensors";
import type { WeatherKind } from "@core/weather";

export type SensedSignals = {
  activity: Activity | undefined;
  ambient: Ambient | undefined;
  ambientOn: boolean;
  ambientBlocked: boolean;
  enableAmbient: () => Promise<void>;
  deskMinutesToday: number | undefined;
  weatherKind: WeatherKind | undefined;
  isOutdoorWeatherGood: boolean | undefined;
  batteryLow: boolean | undefined;
};

/**
 * One place that fuses every passive on-device sense — motion + loudness (mic
 * opt-in), dwell (desk time today), weather (for a saved coarse home), battery.
 * Both home skins and the Now flow read this, so adding a sense touches one file.
 * Each signal degrades to undefined when its source is unavailable.
 */
export function useSensedSignals(): SensedSignals {
  const homeLocation = useStore((s) => s.homeLocation);
  const { activity, ambient, ambientOn, ambientBlocked, enableAmbient } = useSensors();
  const deskMinutesToday = useDwell();
  const weatherKind = useWeather(homeLocation);
  const batteryLow = useBattery();
  return {
    activity,
    ambient,
    ambientOn,
    ambientBlocked,
    enableAmbient,
    deskMinutesToday,
    weatherKind,
    isOutdoorWeatherGood: isGoodOutdoorWeather(weatherKind),
    batteryLow,
  };
}
