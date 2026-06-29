import { useEffect, useState } from "react";
import { isBatteryLow } from "@core/battery";

type BatteryLike = {
  level: number;
  charging: boolean;
  addEventListener: (t: string, cb: () => void) => void;
  removeEventListener: (t: string, cb: () => void) => void;
};

/**
 * A soft "winding down" signal: true when the battery is low and unplugged. No
 * permission; nothing leaves the device. Absent where the Battery API isn't
 * supported (iOS Safari, Firefox) → returns undefined and the ranking carries on.
 */
export function useBattery(): boolean | undefined {
  const [low, setLow] = useState<boolean | undefined>(undefined);
  useEffect(() => {
    if (typeof navigator === "undefined") return;
    const nav = navigator as Navigator & { getBattery?: () => Promise<BatteryLike> };
    if (!nav.getBattery) return;
    let bat: BatteryLike | null = null;
    let cancelled = false;
    const update = () => {
      if (bat) setLow(isBatteryLow(bat.level, bat.charging));
    };
    nav
      .getBattery()
      .then((b) => {
        if (cancelled) return;
        bat = b;
        update();
        b.addEventListener("levelchange", update);
        b.addEventListener("chargingchange", update);
      })
      .catch(() => {
        /* unsupported / blocked — no signal */
      });
    return () => {
      cancelled = true;
      if (bat) {
        bat.removeEventListener("levelchange", update);
        bat.removeEventListener("chargingchange", update);
      }
    };
  }, []);
  return low;
}
