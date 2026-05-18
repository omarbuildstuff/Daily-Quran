import { create } from "zustand";

// Elapsed listening seconds live outside the page component on purpose.
// The 1s tick (and per-word karaoke, handled imperatively) used to sit in
// QuranProjectPage's own state, so every tick re-rendered a 2500-line tree
// full of Framer Motion subtrees — fine on a fast dev machine, janky in
// production. Keeping it here means only the tiny readout/progress leaves
// that subscribe re-render; the player tree and its animations don't.
export const useElapsedStore = create((set) => ({
  elapsed: 0,
  tick: () => set((s) => ({ elapsed: s.elapsed + 1 })),
  reset: () => set({ elapsed: 0 }),
}));
