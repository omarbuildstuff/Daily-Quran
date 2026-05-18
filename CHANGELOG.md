# Changelog

All notable changes to Quran Hub are documented here.

## [0.1.0.0] - 2026-05-18

### Added
- Native iOS app built in SwiftUI — full feature parity with the web PWA including verse tracking, karaoke word highlight, memorization mode, random mode with prefetch, reminders, streak + history, Now Playing + lock screen controls
- iOS design spec documenting architecture decisions

### Fixed
- Elapsed counter no longer ticks during surah loading — timer starts only after the first verse renders (web + iOS)
- Mishary Live (reciter 173) now displays the correct verse from the start — degenerate zero-duration timestamps from the API are post-processed to extend `endMs` to the next verse's start (web + iOS)
- Karaoke word-for-word highlight: first word of a new verse now highlights correctly — `expectedVerseKeyRef` guard prevents stale DOM writes during AnimatePresence exit animations

### Changed
- Elapsed time and active word index moved out of React state into imperative refs / Zustand store (`playbackStore.js`) to avoid re-rendering the full player tree on every tick
- `usePersistentState` SSR-safe rewrite — defaults on server render, loads stored value after hydration to eliminate Next.js hydration mismatches
- Greeting now resolves client-side after hydration (time-of-day dependent)
- Web icons refactored to use even-odd fill rule and per-path layering for correct rendering
