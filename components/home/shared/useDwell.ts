import { useEffect, useState } from "react";
import { advanceDwell, type DwellRecord } from "@core/dwell";

const KEY = "tdd.dwell.v1";

function isDesktop(): boolean {
  if (typeof navigator === "undefined") return false;
  return !(/Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent) || navigator.maxTouchPoints > 1);
}
function todayStr(): string {
  return new Date().toISOString().slice(0, 10);
}

/**
 * Accumulates active minutes at the desk *today*, on-device. Ticks only while the
 * tab is visible on a desktop (≈ you're sitting here); persists per day to
 * localStorage. Returns today's minutes-at-desk (undefined until known / off-desk).
 * Nothing is transmitted.
 */
export function useDwell(): number | undefined {
  const [minutes, setMinutes] = useState<number | undefined>(undefined);

  useEffect(() => {
    if (typeof window === "undefined" || !isDesktop()) return;
    let last = Date.now();

    const load = (): DwellRecord | null => {
      try {
        const raw = window.localStorage.getItem(KEY);
        return raw ? (JSON.parse(raw) as DwellRecord) : null;
      } catch {
        return null;
      }
    };
    const tick = () => {
      const nowMs = Date.now();
      const elapsed = nowMs - last;
      last = nowMs;
      const atDesk = document.visibilityState === "visible";
      const rec = advanceDwell(load(), todayStr(), elapsed, atDesk);
      try {
        window.localStorage.setItem(KEY, JSON.stringify(rec));
      } catch {
        /* storage full / denied — keep going in memory */
      }
      setMinutes(Math.round(rec.deskMs / 60_000));
    };

    tick(); // surface today's accumulated total right away
    const id = window.setInterval(tick, 30_000);
    const onVis = () => {
      last = Date.now(); // don't count time spent away
    };
    document.addEventListener("visibilitychange", onVis);
    return () => {
      window.clearInterval(id);
      document.removeEventListener("visibilitychange", onVis);
    };
  }, []);

  return minutes;
}
