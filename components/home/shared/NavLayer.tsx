"use client";

import { useEffect, useRef, useState } from "react";
import { roundCoarse } from "@/lib/geo";
import {
  buildOverpassQuery,
  parseOverpass,
  nearestPlace,
  compassLabel,
  type NearPlace,
} from "@/lib/places";
import { copy } from "@/lib/copy";

type Status = "idle" | "searching" | "done" | "none" | "fail";

/**
 * A floating, opt-in navigation chip: find the nearest café (an actual Starbucks
 * if there is one) via OpenStreetMap Overpass, and point a real **true-bearing**
 * arrow at it with the distance. Only the coarse current location is sent; nothing
 * is stored. The arrow rotates with the device compass when available, else
 * north-up. Tap to search; fails soft.
 */
export default function NavLayer({ variant = "glass" }: { variant?: "glass" | "soft" } = {}) {
  const chip =
    variant === "soft"
      ? "rounded-[4px] border border-[var(--text)]/15 bg-[var(--surface)] shadow-[0_2px_8px_rgba(0,0,0,0.06)]"
      : "glass rounded-full";
  const [status, setStatus] = useState<Status>("idle");
  const [place, setPlace] = useState<NearPlace | null>(null);
  const [heading, setHeading] = useState(0);
  const headingRef = useRef(0);

  useEffect(() => {
    function onOrient(e: DeviceOrientationEvent & { webkitCompassHeading?: number }) {
      const h = typeof e.webkitCompassHeading === "number"
        ? e.webkitCompassHeading
        : e.alpha != null ? (360 - e.alpha) % 360 : null;
      if (h != null) {
        headingRef.current = h;
        setHeading(h);
      }
    }
    window.addEventListener("deviceorientation", onOrient as EventListener);
    return () => window.removeEventListener("deviceorientation", onOrient as EventListener);
  }, []);

  async function find() {
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      setStatus("fail");
      return;
    }
    setStatus("searching");
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          const here = roundCoarse({ lat: pos.coords.latitude, lng: pos.coords.longitude });
          const res = await fetch("https://overpass-api.de/api/interpreter", {
            method: "POST",
            body: buildOverpassQuery(here, 1600),
          });
          if (!res.ok) throw new Error("overpass");
          const data = await res.json();
          const near = nearestPlace(here, parseOverpass(data), "Starbucks");
          if (near) {
            setPlace(near);
            setStatus("done");
          } else {
            setStatus("none");
          }
        } catch {
          setStatus("fail");
        }
      },
      () => setStatus("fail"),
      { enableHighAccuracy: false, maximumAge: 60000, timeout: 9000 }
    );
  }

  if (status === "idle") {
    return (
      <button
        onClick={find}
        className={`${chip} px-4 py-2 text-[12px] text-[var(--text-secondary)]`}
      >
        {copy.home.navFind}
      </button>
    );
  }

  if (status === "searching") {
    return <p className="text-[12px] text-[var(--text-muted)]">{copy.home.navSearching}</p>;
  }
  if (status === "none") {
    return <p className="text-[12px] text-[var(--text-muted)]">{copy.home.navNone}</p>;
  }
  if (status === "fail" || !place) {
    return <p className="text-[12px] text-[var(--text-muted)]">{copy.home.navFail}</p>;
  }

  const rotation = (place.bearing - heading + 360) % 360;
  return (
    <button onClick={find} className={`${chip} flex items-center gap-2 py-2 pl-2 pr-4`}>
      <span
        className="flex h-7 w-7 items-center justify-center rounded-full bg-[var(--accent-soft)]"
        style={{ transform: `rotate(${rotation}deg)` }}
        aria-hidden
      >
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
          <path d="M12 3 L18 20 L12 16 L6 20 Z" fill="var(--accent-text)" />
        </svg>
      </span>
      <span className="flex flex-col text-left leading-tight">
        <span className="text-[12.5px] text-[var(--text)]">{place.name}</span>
        <span className="text-[11px] text-[var(--text-muted)]">
          {place.distLabel} · 朝{compassLabel(place.bearing)}
          {heading === 0 ? ` ${copy.home.navNorthUp}` : ""}
        </span>
      </span>
    </button>
  );
}
