# Daily Quran

A minimalist Quran listening app for building a daily recitation habit. Pick a duration or a surah, choose a reciter, and listen — the app plays verse after verse without cutting off mid-ayah.

**Live**: [quranster.netlify.app](https://quranster.netlify.app)

## Features

- **Random mode** — Listen for 5, 10, 15 minutes, or a custom duration. Plays random verses and stops only between ayat.
- **Surah mode** — Pick any of the 114 surahs and listen from the first verse to the last.
- **Gapless playback** — Two-audio-element preloading system means verses flow into each other with no silence.
- **The Clear Quran translation** — By Dr. Mustafa Khattab, fetched from the open-source [fawazahmed0/quran-api](https://github.com/fawazahmed0/quran-api).
- **Six reciters** — Mishari al-Afasy, Abdur-Rahman as-Sudais, Mahmoud Khalil Al-Husary, AbdulBaset AbdulSamad, Sa'ud ash-Shuraym, Hani ar-Rifai.
- **Time-aware greetings** — Morning, afternoon, evening, and late-night variants.

## Stack

- React Router v7 (SSR)
- Vite + Hono (dev server)
- Netlify Functions (production SSR)
- Tailwind CSS + Motion (framer-motion)
- Quran.com API (verses, audio) + fawazahmed0/quran-api (translation)

## Development

```bash
cd apps/web
bun install
bun run dev
```

Visit `http://localhost:4000`.

## Deployment

Netlify build command in `netlify.toml`:

```
NETLIFY=true bun install && NETLIFY=true npx react-router build && cp build/server/index.js build/server/server.js
```
