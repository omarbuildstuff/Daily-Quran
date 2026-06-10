// Web Push subscription helpers. Subscriptions are stored server-side
// (Netlify Blobs) so the scheduled function can send reminders while the
// app is closed.

const urlBase64ToUint8Array = (base64String) => {
  try {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
    const raw = window.atob(base64);
    return Uint8Array.from([...raw].map((c) => c.charCodeAt(0)));
  } catch {
    throw new Error("Push notifications aren't configured correctly on the server.");
  }
};

export const pushSupported = () =>
  typeof window !== "undefined" &&
  "serviceWorker" in navigator &&
  "PushManager" in window &&
  typeof Notification !== "undefined";

export const getPushSubscription = async () => {
  if (!pushSupported()) return null;
  const reg = await navigator.serviceWorker.ready;
  return reg.pushManager.getSubscription();
};

// Ensure notification permission + a push subscription. Throws with a
// user-readable message on failure.
export const ensurePushSubscription = async () => {
  if (!pushSupported()) {
    throw new Error("This browser doesn't support push notifications. On iPhone, add the app to your Home Screen first.");
  }
  const permission = await Notification.requestPermission();
  if (permission !== "granted") {
    throw new Error("Notification permission was denied.");
  }
  const reg = await navigator.serviceWorker.ready;
  const existing = await reg.pushManager.getSubscription();
  if (existing) return existing;

  const res = await fetch("/api/push/public-key");
  if (!res.ok) throw new Error("Push notifications aren't set up on the server yet.");
  const { publicKey } = await res.json();
  if (!publicKey) throw new Error("Push notifications aren't configured correctly on the server.");
  return reg.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: urlBase64ToUint8Array(publicKey),
  });
};

// Persist the subscription + reminder schedule server-side.
export const saveReminderSchedule = async (subscription, schedule) => {
  const res = await fetch("/api/push/subscribe", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ subscription: subscription.toJSON(), ...schedule }),
  });
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.error || "Couldn't save the reminder.");
  }
};

export const removeReminderSchedule = async () => {
  const sub = await getPushSubscription().catch(() => null);
  if (!sub) return;
  await fetch("/api/push/subscribe", {
    method: "DELETE",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ endpoint: sub.endpoint }),
  }).catch(() => {});
  await sub.unsubscribe().catch(() => {});
};

// Tell the server we listened today so it suppresses today's reminder.
export const reportListenedToday = async (localDate) => {
  const sub = await getPushSubscription().catch(() => null);
  if (!sub) return;
  fetch("/api/push/listened", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ endpoint: sub.endpoint, localDate }),
  }).catch(() => {});
};
