/**
 * Battery as a soft proxy for *winding down* — a low, unplugged battery often tracks
 * the tail of the day / lower personal energy. It nudges the ranking toward small,
 * restful things and eases off long or high-energy ones. Never a command, never shown
 * loudly. On-device; nothing leaves. (Chrome/Android only; absent elsewhere → no signal.)
 */
export function isBatteryLow(level: number, charging: boolean): boolean {
  return !charging && level <= 0.2;
}
