import { useEffect } from 'react';

export function useDevServerHeartbeat() {
  useEffect(() => {
    if (typeof window === 'undefined' || !import.meta.env.DEV) return;

    let timeout: ReturnType<typeof setTimeout>;

    const keepAlive = () => {
      fetch('/', { method: 'GET' }).catch(() => {});
    };

    const onActivity = () => {
      clearTimeout(timeout);
      timeout = setTimeout(keepAlive, 60_000);
    };

    const events = ['mousemove', 'keydown', 'scroll', 'touchstart'] as const;
    events.forEach((e) => window.addEventListener(e, onActivity, { passive: true }));
    onActivity();

    return () => {
      clearTimeout(timeout);
      events.forEach((e) => window.removeEventListener(e, onActivity));
    };
  }, []);
}
