// Minimal, gentle offline shell for 今天别消失.
// Strategy: network-first for navigations (so updates show, but the app still
// opens offline), cache-first for static assets. Never caches anything sensitive.
const CACHE = "tdd-v1";
const PRECACHE = ["/", "/now", "/seeds", "/traces", "/add", "/settings"];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE).then((c) => c.addAll(PRECACHE)).catch(() => {})
  );
  self.skipWaiting();
});

// Gentle nudges. notificationclick focuses/opens the app. The "push" handler is
// here for future server-sent push (needs a backend + VAPID key); it's harmless
// until then — local nudges are shown directly by the page/SW while the app runs.
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || "/now";
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((list) => {
      for (const c of list) {
        if ("focus" in c) {
          c.navigate?.(url);
          return c.focus();
        }
      }
      return self.clients.openWindow ? self.clients.openWindow(url) : undefined;
    })
  );
});

self.addEventListener("push", (event) => {
  let payload = { title: "今天别消失", body: "现在，也许可以做一点。", url: "/now" };
  try {
    if (event.data) payload = { ...payload, ...event.data.json() };
  } catch {
    /* keep defaults */
  }
  event.waitUntil(
    self.registration.showNotification(payload.title, {
      body: payload.body,
      icon: "/icons/icon-192.png",
      badge: "/icons/icon-192.png",
      data: { url: payload.url },
      tag: "tdd-nudge",
    })
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;

  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  // Navigations: network-first, fall back to cached shell.
  if (req.mode === "navigate") {
    event.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {});
          return res;
        })
        .catch(() => caches.match(req).then((r) => r || caches.match("/")))
    );
    return;
  }

  // Static assets: cache-first, then network (and cache it).
  event.respondWith(
    caches.match(req).then(
      (cached) =>
        cached ||
        fetch(req).then((res) => {
          if (res.ok && (url.pathname.startsWith("/icons/") || url.pathname.startsWith("/_next/static/"))) {
            const copy = res.clone();
            caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {});
          }
          return res;
        })
    )
  );
});
