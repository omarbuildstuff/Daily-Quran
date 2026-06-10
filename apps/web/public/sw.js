// Quran Hub service worker — push notifications + offline playback.
//
// Caches (stable names so user downloads survive SW updates):
//   quran-audio-v1  — full-surah mp3s the user explicitly downloaded
//   quran-api-v1    — verse/timestamp/translation JSON (network-first)
//   quran-shell-v1  — app shell + same-origin static assets
const AUDIO_CACHE = 'quran-audio-v1';
const API_CACHE = 'quran-api-v1';
const SHELL_CACHE = 'quran-shell-v1';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

// ─── Push notifications ─────────────────────────────────────────────────────
// Fired by the scheduled reminder function even when the app is closed.
self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch {
    // Non-JSON payload — fall back to defaults
  }
  const title = data.title || 'Time for your daily Quran 🤲';
  event.waitUntil(
    self.registration.showNotification(title, {
      body: data.body || 'A few quiet minutes with the Quran.',
      icon: '/android-chrome-192x192.png',
      badge: '/android-chrome-192x192.png',
      tag: data.tag || 'daily-reminder',
      data: { url: data.url || '/' },
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = event.notification.data?.url || '/';
  event.waitUntil(
    self.clients.matchAll({ type: 'window' }).then((clients) => {
      const existing = clients.find((c) => c.url.startsWith(self.location.origin));
      if (existing) return existing.focus();
      return self.clients.openWindow(url);
    })
  );
});

// ─── Offline fetch handling ──────────────────────────────────────────────────

const isAudioRequest = (request, url) =>
  request.destination === 'audio' ||
  /\.(mp3|m4a|ogg)(\?|$)/.test(url.pathname);

const isQuranApi = (url) =>
  url.hostname === 'api.quran.com' || url.hostname === 'cdn.jsdelivr.net';

// Serve a cached full-body audio response, honouring Range requests —
// Safari refuses to play/seek audio without 206 partial responses.
async function serveAudioFromCache(cached, request) {
  const rangeHeader = request.headers.get('range');
  // Opaque (no-cors) responses can't be sliced — return as-is and hope the
  // browser tolerates a 200 for a range request (Chrome does).
  if (!rangeHeader || cached.status === 0) return cached;
  const match = /bytes=(\d+)-(\d+)?/.exec(rangeHeader);
  if (!match) return cached;
  const buf = await cached.arrayBuffer();
  const start = Number(match[1]);
  const end = match[2] ? Math.min(Number(match[2]), buf.byteLength - 1) : buf.byteLength - 1;
  if (start >= buf.byteLength) {
    return new Response(null, {
      status: 416,
      headers: { 'Content-Range': `bytes */${buf.byteLength}` },
    });
  }
  return new Response(buf.slice(start, end + 1), {
    status: 206,
    statusText: 'Partial Content',
    headers: {
      'Content-Type': cached.headers.get('Content-Type') || 'audio/mpeg',
      'Content-Range': `bytes ${start}-${end}/${buf.byteLength}`,
      'Content-Length': String(end - start + 1),
      'Accept-Ranges': 'bytes',
    },
  });
}

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);

  // Audio: cache-first (only explicit downloads are ever written to the cache).
  if (isAudioRequest(request, url)) {
    event.respondWith(
      caches.open(AUDIO_CACHE).then(async (cache) => {
        const cached = await cache.match(request.url, { ignoreVary: true });
        if (cached) return serveAudioFromCache(cached, request);
        return fetch(request);
      })
    );
    return;
  }

  // Quran APIs: network-first, fall back to cache so previously fetched
  // (downloaded) surahs keep working offline.
  if (isQuranApi(url)) {
    event.respondWith(
      caches.open(API_CACHE).then(async (cache) => {
        try {
          const fresh = await fetch(request);
          if (fresh.ok) cache.put(request, fresh.clone());
          return fresh;
        } catch (err) {
          const cached = await cache.match(request);
          if (cached) return cached;
          throw err;
        }
      })
    );
    return;
  }

  // Navigations: network-first, cached shell when offline.
  if (request.mode === 'navigate') {
    event.respondWith(
      caches.open(SHELL_CACHE).then(async (cache) => {
        try {
          const fresh = await fetch(request);
          if (fresh.ok && url.pathname === '/') cache.put('/', fresh.clone());
          return fresh;
        } catch (err) {
          const cached = await cache.match('/');
          if (cached) return cached;
          throw err;
        }
      })
    );
    return;
  }

  // Same-origin static assets (fonts, icons, hashed JS/CSS): stale-while-revalidate.
  // Skipped on localhost — caching Vite's dev modules serves stale code/CSS.
  const isLocalDev = self.location.hostname === 'localhost' || self.location.hostname === '127.0.0.1';
  if (url.origin === self.location.origin && !isLocalDev) {
    event.respondWith(
      caches.open(SHELL_CACHE).then(async (cache) => {
        const cached = await cache.match(request);
        const network = fetch(request)
          .then((fresh) => {
            if (fresh.ok) cache.put(request, fresh.clone());
            return fresh;
          })
          .catch(() => cached);
        return cached || network;
      })
    );
  }
});
