/**
 * Web Push groundwork — the client seam for server-sent nudges that can reach a
 * closed app. No key is hardcoded: the VAPID public key comes from
 * `NEXT_PUBLIC_VAPID_PUBLIC_KEY`. Until a backend exists to store subscriptions
 * and send pushes, this stays dormant (subscribe returns null without a key).
 * Local in-session nudges still work without any of this.
 */

export function getVapidPublicKey(): string | undefined {
  const k = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY;
  return k && k.length > 0 ? k : undefined;
}

export function pushSupported(): boolean {
  return (
    typeof window !== "undefined" &&
    "serviceWorker" in navigator &&
    "PushManager" in window &&
    "Notification" in window
  );
}

/** Decode a base64url VAPID key into the Uint8Array the Push API expects. */
export function urlBase64ToUint8Array(base64: string): Uint8Array {
  const padding = "=".repeat((4 - (base64.length % 4)) % 4);
  const normalized = (base64 + padding).replace(/-/g, "+").replace(/_/g, "/");
  const raw = atob(normalized);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

/**
 * Ensure a push subscription exists (reusing any current one). Returns the
 * subscription to hand to a backend later, or null when not possible/configured.
 * Never prompts on its own beyond the push subscribe; callers gate on consent.
 */
export async function ensurePushSubscription(
  reg: ServiceWorkerRegistration
): Promise<PushSubscription | null> {
  try {
    const key = getVapidPublicKey();
    if (!key || !pushSupported()) return null;
    if (Notification.permission !== "granted") return null;
    const existing = await reg.pushManager.getSubscription();
    if (existing) return existing;
    return await reg.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(key) as BufferSource,
    });
  } catch {
    return null; // push is an enhancement; never block the app
  }
}
