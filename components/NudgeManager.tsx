"use client";

import { useEffect, useRef } from "react";
import { useStore } from "@/lib/store";
import { storage, type RemindersToday } from "@/lib/storage";
import { buildAmbientContext, guessLocation } from "@/lib/ambient";
import { recommend } from "@/lib/scoring";
import { shouldNudge, bumpReminders, nudgeText } from "@/lib/nudge";

const CHECK_EVERY_MS = 5 * 60 * 1000; // every 5 minutes

function isMobileDevice(): boolean {
  if (typeof navigator === "undefined") return false;
  return /Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent) || navigator.maxTouchPoints > 1;
}

async function showNudge(title: string, body: string) {
  try {
    if ("serviceWorker" in navigator) {
      const reg = await navigator.serviceWorker.getRegistration();
      if (reg) {
        await reg.showNotification(title, {
          body,
          icon: "/icons/icon-192.png",
          badge: "/icons/icon-192.png",
          tag: "tdd-nudge",
          data: { url: "/now" },
        });
        return;
      }
    }
    new Notification(title, { body, icon: "/icons/icon-192.png" });
  } catch {
    /* notifications are an enhancement — never throw */
  }
}

/**
 * Fires a gentle nudge while the app is open but backgrounded (a tab you left)
 * and a fitting moment passes — honouring quiet-hours + the daily budget. It
 * never nudges while you're looking at the app, and is off unless you enabled
 * it and granted permission. (True closed-app push needs a backend + VAPID key;
 * the SW already has a push handler for when that's added.)
 */
export default function NudgeManager() {
  const hydrated = useStore((s) => s.hydrated);
  const settings = useStore((s) => s.settings);
  const seeds = useStore((s) => s.seeds);
  const lastPick = useStore((s) => s.lastPick);
  const remindersRef = useRef<RemindersToday | null>(null);

  useEffect(() => {
    if (!hydrated) return;
    if (typeof window === "undefined" || typeof Notification === "undefined") return;
    remindersRef.current = storage.loadReminders();

    function tick() {
      if (!settings.nudgesEnabled) return;
      if (Notification.permission !== "granted") return;
      if (document.visibilityState !== "hidden") return; // don't nudge if you're here

      const now = new Date();
      if (!shouldNudge(settings, remindersRef.current, now)) return;

      const ctx = buildAmbientContext({
        now,
        isMobile: isMobileDevice(),
        locationHint: guessLocation(now, isMobileDevice()),
        energy: lastPick.energy,
      });
      const [top] = recommend(seeds, ctx, { limit: 1 });
      if (!top) return;

      const { title, body } = nudgeText(top);
      void showNudge(title, body);
      const next = bumpReminders(remindersRef.current, now);
      remindersRef.current = next;
      storage.saveReminders(next);
    }

    const id = window.setInterval(tick, CHECK_EVERY_MS);
    return () => window.clearInterval(id);
  }, [hydrated, settings, seeds, lastPick.energy]);

  return null;
}
