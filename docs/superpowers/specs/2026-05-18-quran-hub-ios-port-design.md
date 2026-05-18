# Quran Hub — Native iOS (Swift) Port — Design

**Date:** 2026-05-18
**Goal:** Recreate the `apps/web` PWA ("Quran Hub | Your Daily Quran") as a native Swift app that matches every feature, transition and animation, and is App-Store-submittable. Output in `apps/mobile/QuranHub`.

## Locked decisions

| Decision | Choice |
|---|---|
| Location | `apps/mobile/QuranHub` (non-destructive; RN scaffold untouched) |
| UI framework | SwiftUI |
| Min iOS | iOS 18 (builds/runs on iOS 26.2 sim) |
| Audio + alerts | Full native: background audio, lock-screen / Control Center Now Playing, daily local notification |
| Offline scope | Full offline text — all 114 surahs Arabic (Uthmani) + Khattab English bundled; audio streamed |
| Signing | App-Store-ready; automatic signing, Team blank, bundle `com.quranhub.app` |
| Identity | Display name "Quran Hub", bundle `com.quranhub.app` |
| Verification | `xcodebuild` + iOS 26.2 simulator |
| Project tool | xcodegen (`project.yml`) → `QuranHub.xcodeproj` |

## Source PWA summary

Single React page (`apps/web/src/app/page.jsx`, 2576 lines) + `root.tsx`, `sw.js`, `site.webmanifest`, `chapters.js`. Three views (`setup` / `playing` / `finished`), framer-motion (`motion` v12) transitions, 23 `localStorage` keys (prefix `quranaday.v1.`), `api.quran.com/api/v4` + `cdn.jsdelivr.net` (fawazahmed0 `eng-mustafakhattaba`) APIs. Custom fonts Thmanyah Serif Display / Arsenica / Resolide + Inter/Fraunces/Playfair. Warm palette + oklch gold/sage, shadows card/dropdown/overlay.

## Feature inventory (parity bar)

- **Setup:** time-based greeting (5 buckets), mode toggle (Randomize / Choose surah), surah picker (114), duration buttons 5/10/15 + custom minutes, mood toggle → 8 moods (curated surah pools), memorization mode (start/end verse + repeat), reciter picker (10), resume banner (<24h bookmark), daily-reminder banner, animated gold underline.
- **Playing:** loader (3 staggered dots + surah/reciter), verse display (Arabic Uthmani RTL + Khattab EN), karaoke active-word highlight (gold/green) synced to per-word segments, tap/hover word tooltip (translation + transliteration), auto-scroll to focused language on verse enter, playback dock (play/pause, save-verse heart, time-or-verse readout), progress bar (scrubbable in surah mode / read-only timer mode), gradient fade, End Session.
- **Finished:** rotated gradient card + infinite pulsing ring, "Barakallahu Feekum.", context message, streak reveal (delayed).
- **Settings sheet:** saved verses entry, daily reminder toggle + time, karaoke toggle + color, word-tooltip toggle, auto-stop toggle, language display (Arabic/English/Both), focus-on-new-verse (Both only).
- **Bookmarks sheet:** saved verses list, RTL text + translation, remove.
- **Logic:** single-file audio per surah, active verse from `startMs/endMs`, karaoke word from `[idx,start,end]` segments, random mode with mood pools + no-repeat + prefetch + seamless next, surah mode start→end, memorization loop/stop (`endMs-60`), timer auto-stop within 200ms of verse end, daily streak (consecutive days, soft reset), per-surah listen history, resume bookmark, daily reminder (was 60s SW poll → native daily notification), wake-lock (→ background audio + idle-timer-off).

## Architecture (Approach A — pure SwiftUI + single `@Observable`)

```
apps/mobile/QuranHub/
  project.yml                       # xcodegen
  scripts/gen-quran-text.mjs        # build-prep: fetch+merge offline corpus
  Sources/
    QuranHubApp.swift               # @main, AVAudioSession, notif delegate
    Model/  AppModel.swift Persistence.swift Models.swift
            Chapters.swift Moods.swift Reciters.swift Durations.swift Greeting.swift
    Audio/  AudioEngine.swift
    Net/    QuranAPI.swift QuranText.swift
    Notifications/ Reminders.swift
    Views/  RootView.swift SetupView.swift PlayingView.swift FinishedView.swift
            SettingsSheet.swift BookmarksSheet.swift Theme.swift
            Components/  Bi.swift PillToggle.swift Segmented.swift Banners.swift PressableButton.swift
    Resources/ Fonts/* Data/quran-text.json Assets.xcassets Info.plist
```

- **State/persistence:** `AppModel` (`@Observable`) holds all 23 persisted keys with identical defaults; `Persistence` mirrors them to `UserDefaults` under `quranaday.v1.<key>` as JSON. Session-only state non-persisted.
- **Audio:** `AVPlayer`, `addPeriodicTimeObserver` (~20 Hz) replaces `onTimeUpdate`+rAF; computes verse/word, memorization, timer auto-stop, prefetch + seamless next, surah-end. `AVAudioSession .playback` (background), `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter`, `isIdleTimerDisabled` while playing (wake-lock intent).
- **Data:** offline text from bundled `quran-text.json`; live `chapter_recitations/{r}/{s}?segments=true` (audio URL, verse timestamps, word segments) + `verses/by_chapter` words (per-word EN/translit for karaoke + tooltips). Word/segment fetch failure degrades gracefully; audio failure → same error toast.
- **Notifications:** `UNUserNotificationCenter` daily calendar trigger at `reminderTime` + in-app banner parity; tap focuses app (= `sw.js` `notificationclick`).
- **Animation parity:** every motion mapped 1:1 — view switch (opacity+y, 0.2/0.3 easeOut, exit-before-enter), verse change (y±16, 0.3), section reveals (y-8, 0.25, height collapse), toggle knob (180ms), button hover/active scale, gold underline (scaleX 0→1, 0.4), loader (1.4s staggered), finished ring (infinite 2s), streak (delay 0.4), modals (backdrop 0.2 / panel y20 0.2), banners (y-8 0.3). `accessibilityReduceMotion` honored.
- **App Store:** `UIBackgroundModes:[audio]`, no tracking / no data collected, notification permission in-context, launch screen, full AppIcon, portrait iPhone (iPad universal ok), no private APIs.

## Out of scope (not in PWA)

Per-word **offline** (segments are audio-derived → network only), accounts/sync, the `__create` sandbox/dev-overlay/screenshot harness.

## Verification

`xcodegen generate` → `xcodebuild -scheme QuranHub -destination 'iOS Simulator,OS=26.2'` builds clean; boot sim, smoke-test setup→playing→finished, settings, bookmarks, offline text, reminder scheduling.
