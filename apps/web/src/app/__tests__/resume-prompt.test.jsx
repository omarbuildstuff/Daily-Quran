// Verifies the "Resume / Pick up where you left off" prompt actually renders
// on the setup view, driven by the persisted `lastSession` bookmark, and that
// the 7-day eligibility window is honored. Mounts the real page component in
// jsdom — no mocking of the resume logic itself.
import { render, screen, waitFor, cleanup } from "@testing-library/react";
import { afterEach, beforeAll, beforeEach, describe, expect, it } from "vitest";
import QuranProjectPage from "../page.jsx";

const STORAGE_PREFIX = "quranaday.v1.";
const LAST_SESSION_KEY = STORAGE_PREFIX + "lastSession";

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;

function seedBookmark({ agoMs, surahName = "Al-Fatihah", verseKey = "1:4", surah = 1 }) {
  window.localStorage.setItem(
    LAST_SESSION_KEY,
    JSON.stringify({
      surah,
      surahName,
      verseKey,
      mode: "surah",
      savedAt: Date.now() - agoMs,
    }),
  );
}

// motion/react and the layout probe at browser APIs jsdom doesn't ship.
beforeAll(() => {
  if (!window.matchMedia) {
    window.matchMedia = (query) => ({
      matches: false,
      media: query,
      onchange: null,
      addListener: () => {},
      removeListener: () => {},
      addEventListener: () => {},
      removeEventListener: () => {},
      dispatchEvent: () => false,
    });
  }
  for (const name of ["ResizeObserver", "IntersectionObserver"]) {
    if (!window[name]) {
      window[name] = class {
        observe() {}
        unobserve() {}
        disconnect() {}
      };
    }
  }
  // jsdom doesn't implement media playback; the page pauses audio in an effect.
  HTMLMediaElement.prototype.play = () => Promise.resolve();
  HTMLMediaElement.prototype.pause = () => {};
  HTMLMediaElement.prototype.load = () => {};
});

beforeEach(() => {
  window.localStorage.clear();
});

afterEach(() => {
  cleanup();
});

describe("Resume listening prompt", () => {
  it("shows the prompt for a bookmark from 1 hour ago", async () => {
    seedBookmark({ agoMs: 1 * HOUR, surahName: "Al-Fatihah", verseKey: "1:4" });
    render(<QuranProjectPage />);

    await waitFor(() =>
      expect(screen.getByText(/pick up where you left off/i)).toBeInTheDocument(),
    );
    // The detail line names the surah + verse and a Resume button is present.
    expect(screen.getByText(/Al-Fatihah/)).toBeInTheDocument();
    expect(screen.getByText(/1:4/)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /^resume$/i })).toBeInTheDocument();
  });

  it("still shows for a 3-day-old bookmark (proves window is >24h)", async () => {
    seedBookmark({ agoMs: 3 * DAY });
    render(<QuranProjectPage />);

    await waitFor(() =>
      expect(screen.getByText(/pick up where you left off/i)).toBeInTheDocument(),
    );
  });

  it("still shows just inside the 7-day window (6 days, 23 hours)", async () => {
    seedBookmark({ agoMs: 7 * DAY - HOUR });
    render(<QuranProjectPage />);

    await waitFor(() =>
      expect(screen.getByText(/pick up where you left off/i)).toBeInTheDocument(),
    );
  });

  it("does NOT show for an 8-day-old bookmark (past the 7-day window)", async () => {
    seedBookmark({ agoMs: 8 * DAY });
    render(<QuranProjectPage />);

    // Give effects a chance to run, then assert the prompt is absent.
    await new Promise((r) => setTimeout(r, 100));
    expect(screen.queryByText(/pick up where you left off/i)).not.toBeInTheDocument();
  });

  it("does NOT show when there is no bookmark at all", async () => {
    render(<QuranProjectPage />);
    await new Promise((r) => setTimeout(r, 100));
    expect(screen.queryByText(/pick up where you left off/i)).not.toBeInTheDocument();
  });
});
