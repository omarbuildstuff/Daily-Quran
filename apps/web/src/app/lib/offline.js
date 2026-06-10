// Offline surah downloads — full-surah mp3s stored in the Cache API. The
// service worker serves these cache-first (with Range support), so a
// downloaded surah plays with no connection.
const AUDIO_CACHE = "quran-audio-v1";

export const offlineSupported = () =>
  typeof window !== "undefined" && "caches" in window;

export const downloadAudio = async (audioUrl) => {
  const cache = await caches.open(AUDIO_CACHE);
  let response;
  try {
    response = await fetch(audioUrl);
    if (!response.ok) throw new Error(`Audio fetch failed: ${response.status}`);
  } catch {
    // CDN without CORS — store an opaque copy (still playable from cache)
    response = await fetch(audioUrl, { mode: "no-cors" });
  }
  await cache.put(audioUrl, response);
};

export const removeAudio = async (audioUrl) => {
  const cache = await caches.open(AUDIO_CACHE);
  await cache.delete(audioUrl);
};

export const isAudioCached = async (audioUrl) => {
  const cache = await caches.open(AUDIO_CACHE);
  return Boolean(await cache.match(audioUrl));
};
