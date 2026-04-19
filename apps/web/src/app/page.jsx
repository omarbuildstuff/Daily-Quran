"use client";

import React, { useState, useEffect, useRef, useCallback } from "react";
import {
  Play,
  Pause,
  Heart,
  Globe,
  Clock,
  ChevronRight,
} from "lucide-react";
import { motion, AnimatePresence } from "motion/react";
import { chapters } from "../data/chapters";

const RECITERS = [
  { id: 7, name: "Mishari Rashid al-Afasy" },
  { id: 3, name: "Abdur-Rahman as-Sudais" },
  { id: 12, name: "Mahmoud Khalil Al-Husary" },
  { id: 2, name: "AbdulBaset AbdulSamad" },
  { id: 10, name: "Sa'ud ash-Shuraym" },
  { id: 5, name: "Hani ar-Rifai" },
];

const DURATIONS = [
  { label: "5 min", value: 5 * 60 },
  { label: "10 min", value: 10 * 60 },
  { label: "15 min", value: 15 * 60 },
];

const getGreeting = () => {
  const hour = new Date().getHours();
  if (hour < 5) return { line1: "Late night?", line2: "Let the Quran accompany you." };
  if (hour < 12) return { line1: "Good morning.", line2: "Time to listen." };
  if (hour < 17) return { line1: "Bismillah.", line2: "Let's begin." };
  if (hour < 21) return { line1: "Good evening.", line2: "Unwind with Quran." };
  return { line1: "Wind down.", line2: "Listen before you sleep." };
};

export default function QuranProjectPage() {
  const [view, setView] = useState("setup"); // 'setup' | 'playing' | 'finished'
  const [reciterId, setReciterId] = useState(7);
  const [targetDuration, setTargetDuration] = useState(300);
  const [currentAyah, setCurrentAyah] = useState(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [elapsedTime, setElapsedTime] = useState(0);
  const [startTime, setStartTime] = useState(0);
  const [loading, setLoading] = useState(false);
  const [customMinutes, setCustomMinutes] = useState("");
  const [error, setError] = useState(null);
  const [mode, setMode] = useState("random"); // 'random' | 'surah'
  const [selectedSurah, setSelectedSurah] = useState(1);
  const [surahTimerEnabled, setSurahTimerEnabled] = useState(false);

  // Single audio element — plays the full surah as one file (no gap problem)
  const audioRef = useRef(null);

  // Current surah's data: full audio URL + per-verse timestamps + per-verse text/translation
  // Shape: { surah: number, audioUrl: string, verses: [{ num, text, translation, startMs, endMs }] }
  const surahDataRef = useRef(null);
  // Prefetched next surah (for random mode when current finishes before timer ends)
  const nextSurahDataRef = useRef(null);

  const timerRef = useRef(null);

  // ─────────────────────────────────────────────────────────────────────────────
  // Fetch full surah: audio URL + verse timestamps + per-verse text + translations
  // All in one bundled call. Returns { surah, audioUrl, surahName, verses: [{num, text, translation, startMs, endMs}] }
  const fetchSurahData = useCallback(
    async (surahId) => {
      const [chapterAudioRes, versesRes, translationsRes] = await Promise.all([
        fetch(
          `https://api.quran.com/api/v4/chapter_recitations/${reciterId}/${surahId}?segments=true`,
        ),
        fetch(
          `https://api.quran.com/api/v4/verses/by_chapter/${surahId}?fields=text_uthmani&per_page=300`,
        ),
        fetch(
          `https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/eng-mustafakhattaba/${surahId}.json`,
        ),
      ]);

      if (!chapterAudioRes.ok) throw new Error(`Audio API error: ${chapterAudioRes.status}`);
      if (!versesRes.ok) throw new Error(`Verse API error: ${versesRes.status}`);

      const [chapterAudio, versesData, translationsData] = await Promise.all([
        chapterAudioRes.json(),
        versesRes.json(),
        translationsRes.ok ? translationsRes.json() : null,
      ]);

      if (!chapterAudio.audio_file) throw new Error("Chapter audio not found");

      const timestamps = chapterAudio.audio_file.timestamps || [];
      const translationByVerse = {};
      if (translationsData?.chapter) {
        translationsData.chapter.forEach((t) => {
          translationByVerse[t.verse] = (t.text || "")
            .replace(/<sup[^>]*>.*?<\/sup>/gi, "")
            .replace(/<[^>]*>/g, "");
        });
      }

      const verses = versesData.verses.map((v) => {
        const ts = timestamps.find((t) => t.verse_key === v.verse_key);
        return {
          num: v.verse_number,
          key: v.verse_key,
          text: v.text_uthmani,
          translation: translationByVerse[v.verse_number] || "Translation not available",
          startMs: ts?.timestamp_from ?? 0,
          endMs: ts?.timestamp_to ?? 0,
        };
      });

      return {
        surah: surahId,
        audioUrl: chapterAudio.audio_file.audio_url,
        surahName:
          chapters.find((c) => c.id === surahId)?.name_simple || `Surah ${surahId}`,
        verses,
      };
    },
    [reciterId],
  );

  // ─────────────────────────────────────────────────────────────────────────────
  // Active verse tracking — on timeupdate, find which verse is playing
  // ─────────────────────────────────────────────────────────────────────────────

  const updateCurrentVerse = useCallback(() => {
    const el = audioRef.current;
    const sd = surahDataRef.current;
    if (!el || !sd) return;
    const currentMs = el.currentTime * 1000;
    // Find the verse whose time range contains currentMs
    const active =
      sd.verses.find((v) => currentMs >= v.startMs && currentMs < v.endMs) ||
      sd.verses[sd.verses.length - 1]; // fallback to last verse at end
    if (!active) return;
    // Update state only if it changed
    setCurrentAyah((prev) => {
      if (prev && prev.key === active.key) return prev;
      return {
        key: active.key,
        text: active.text,
        translation: active.translation,
        surahName: sd.surahName,
      };
    });
  }, []);

  const handleTimeUpdate = useCallback(() => {
    updateCurrentVerse();

    // Timer-based end condition (random mode OR surah mode with optional timer enabled)
    const timerActive = mode === "random" || (mode === "surah" && surahTimerEnabled);
    if (timerActive) {
      const now = Date.now();
      const elapsed = (now - startTime) / 1000;
      if (elapsed >= targetDuration) {
        // Wait for end of current verse before stopping
        const el = audioRef.current;
        const sd = surahDataRef.current;
        if (!el || !sd) return;
        const currentMs = el.currentTime * 1000;
        const active = sd.verses.find(
          (v) => currentMs >= v.startMs && currentMs < v.endMs,
        );
        // If we're within ~200ms of the end of the current verse, stop now
        if (active && active.endMs - currentMs <= 200) {
          el.pause();
          setView("finished");
          setIsPlaying(false);
        }
      }
    }
  }, [updateCurrentVerse, mode, surahTimerEnabled, startTime, targetDuration]);

  // Prefetch a random surah (for random mode when current surah ends before timer)
  const prefetchRandomSurah = useCallback(async () => {
    try {
      const randomId = Math.floor(Math.random() * 114) + 1;
      const data = await fetchSurahData(randomId);
      nextSurahDataRef.current = data;
    } catch (err) {
      nextSurahDataRef.current = null;
    }
  }, [fetchSurahData]);

  const loadAndPlaySurah = useCallback(
    async (surahId, preloaded) => {
      setLoading(true);
      setError(null);
      try {
        const data = preloaded || (await fetchSurahData(surahId));
        surahDataRef.current = data;

        // Display the first verse immediately
        if (data.verses.length > 0) {
          const v0 = data.verses[0];
          setCurrentAyah({
            key: v0.key,
            text: v0.text,
            translation: v0.translation,
            surahName: data.surahName,
          });
        }

        const el = audioRef.current;
        if (el) {
          el.src = data.audioUrl;
          el.load();
          el.play().catch((e) => console.error("Playback error:", e));
        }
        setLoading(false);

        // In random mode, prefetch the next surah so we can continue seamlessly
        if (mode === "random") {
          prefetchRandomSurah();
        }
      } catch (err) {
        console.error("Load surah error:", err);
        setError(err.message);
        setLoading(false);
      }
    },
    [fetchSurahData, mode, prefetchRandomSurah],
  );

  // When the full surah audio naturally ends (via onEnded)
  const handleSurahEnded = useCallback(() => {
    if (mode === "surah") {
      // Surah mode: session complete
      setView("finished");
      setIsPlaying(false);
      return;
    }
    // Random mode: if timer done, finish; else play another surah
    const elapsed = (Date.now() - startTime) / 1000;
    if (elapsed >= targetDuration) {
      setView("finished");
      setIsPlaying(false);
      return;
    }
    // Play the prefetched next surah, or fetch a new one
    const preloaded = nextSurahDataRef.current;
    nextSurahDataRef.current = null;
    if (preloaded) {
      loadAndPlaySurah(preloaded.surah, preloaded);
    } else {
      const randomId = Math.floor(Math.random() * 114) + 1;
      loadAndPlaySurah(randomId);
    }
  }, [mode, startTime, targetDuration, loadAndPlaySurah]);

  const startPlayback = useCallback(() => {
    const startSurah =
      mode === "surah" ? selectedSurah : Math.floor(Math.random() * 114) + 1;
    surahDataRef.current = null;
    nextSurahDataRef.current = null;

    setElapsedTime(0);
    setStartTime(Date.now());
    setView("playing");
    setIsPlaying(true);
    loadAndPlaySurah(startSurah);
  }, [mode, selectedSurah, loadAndPlaySurah]);

  // Pause/resume: toggle the audio element directly
  useEffect(() => {
    const el = audioRef.current;
    if (el) {
      if (isPlaying) {
        el.play().catch((e) => console.error("Playback error:", e));
      } else {
        el.pause();
      }
    }
  }, [isPlaying]);

  const handleEndSession = useCallback(() => {
    setView("setup");
    setIsPlaying(false);
    const el = audioRef.current;
    if (el) {
      el.pause();
      el.removeAttribute("src");
      el.load();
    }
    surahDataRef.current = null;
    nextSurahDataRef.current = null;
    setCurrentAyah(null);
  }, []);

  const handleRepeat = useCallback(() => {
    startPlayback();
  }, [startPlayback]);

  // ─────────────────────────────────────────────────────────────────────────────
  // Elapsed time timer
  // ─────────────────────────────────────────────────────────────────────────────

  useEffect(() => {
    if (view === "playing" && isPlaying) {
      timerRef.current = setInterval(() => {
        setElapsedTime((prev) => prev + 1);
      }, 1000);
    } else {
      clearInterval(timerRef.current);
    }
    return () => clearInterval(timerRef.current);
  }, [view, isPlaying]);

  // ─────────────────────────────────────────────────────────────────────────────
  // Cleanup on unmount
  // ─────────────────────────────────────────────────────────────────────────────

  useEffect(() => {
    return () => {
      clearInterval(timerRef.current);
    };
  }, []);

  // ─────────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  const formatTime = (seconds) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, "0")}`;
  };

  // ─────────────────────────────────────────────────────────────────────────────
  // Render
  // ─────────────────────────────────────────────────────────────────────────────

  return (
    <div className="app-shell text-[#1a1a1a] font-inter selection:bg-black selection:text-white">
      <audio
        ref={audioRef}
        onEnded={handleSurahEnded}
        onTimeUpdate={handleTimeUpdate}
        preload="auto"
      />

      <div className="app-container max-w-screen-md mx-auto flex flex-col px-6 md:px-12 pt-6 md:pt-12 pb-20 md:pb-24">
        {/* Simple Header */}
        <header className="flex justify-between items-center mb-12 relative z-10">
          <div className="flex items-center gap-3">
            <img
              src="/quran-hub-logo.png"
              alt="Quran Hub"
              className="h-12 w-auto"
            />
            <div>
              <h1 className="text-lg font-sans font-bold tracking-tight leading-none">
                Quran Hub
              </h1>
              <p className="text-[10px] font-sans uppercase tracking-[0.2em] text-[#999] mt-1">
                Daily Listening
              </p>
            </div>
          </div>
          {view !== "setup" && (
            <button
              onClick={handleEndSession}
              className="px-4 py-2 bg-white/50 backdrop-blur-md border border-[#e5e5e0] rounded-full text-xs font-bold uppercase tracking-widest hover:bg-black hover:text-white transition-all duration-300"
            >
              End Session
            </button>
          )}
        </header>

        <main className="flex-1 flex flex-col justify-center relative">
          <AnimatePresence mode="wait">
            {view === "setup" && (
              <motion.div
                key="setup"
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 1.05 }}
                className="space-y-12"
              >
                <div className="space-y-6">
                  <motion.div
                    initial={{ width: 0 }}
                    animate={{ width: 40 }}
                    className="h-1"
                    style={{ backgroundColor: "var(--accent-gold)" }}
                  />
                  <h2 className="text-5xl md:text-7xl font-resolide font-bold leading-[1.1] tracking-tight">
                    {getGreeting().line1} <br />
                    {getGreeting().line2}
                  </h2>
                  <p className="text-xl text-[#666] max-w-sm leading-relaxed font-light">
                    {mode === "surah"
                      ? "Pick a surah. Listen from the first verse to the last."
                      : "Choose how long and who recites. We'll never cut off mid-verse."}
                  </p>
                </div>

                <div className="grid gap-8">
                  {/* Mode Toggle */}
                  <div className="flex gap-1 bg-[#f0f0ec] rounded-2xl p-1">
                    <button
                      onClick={() => setMode("random")}
                      className={`flex-1 py-3 rounded-xl text-sm font-bold transition-all duration-300 ${
                        mode === "random"
                          ? "bg-white text-black shadow-sm"
                          : "text-[#999] hover:text-[#666]"
                      }`}
                    >
                      Randomize Surah
                    </button>
                    <button
                      onClick={() => setMode("surah")}
                      className={`flex-1 py-3 rounded-xl text-sm font-bold transition-all duration-300 ${
                        mode === "surah"
                          ? "bg-white text-black shadow-sm"
                          : "text-[#999] hover:text-[#666]"
                      }`}
                    >
                      Choose Surah
                    </button>
                  </div>

                  <AnimatePresence mode="wait">
                    {mode === "surah" ? (
                      <motion.div
                        key="surah-picker"
                        initial={{ opacity: 0, y: 12 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: -12 }}
                        transition={{ duration: 0.25, ease: "easeOut" }}
                        className="space-y-4"
                      >
                        <div className="flex items-center gap-2 text-[#999]">
                          <ChevronRight size={14} />
                          <label className="text-xs font-mono uppercase tracking-widest">
                            Which surah?
                          </label>
                        </div>
                        <div className="relative">
                          <select
                            value={selectedSurah}
                            onChange={(e) => setSelectedSurah(Number(e.target.value))}
                            className="w-full appearance-none bg-white border border-[#e5e5e0] rounded-2xl px-6 py-5 text-lg font-bold focus:outline-none focus:ring-2 focus:ring-black/10 cursor-pointer"
                          >
                            {chapters.map((c) => (
                              <option key={c.id} value={c.id}>
                                {c.id}. {c.name_simple} ({c.name_arabic})
                              </option>
                            ))}
                          </select>
                          <ChevronRight
                            size={18}
                            className="absolute right-4 top-1/2 -translate-y-1/2 text-[#999] rotate-90 pointer-events-none"
                          />
                        </div>

                        {/* Optional timer toggle for surah mode */}
                        <div className="pt-4">
                          <button
                            onClick={() => setSurahTimerEnabled(!surahTimerEnabled)}
                            className="flex items-center gap-3 text-xs font-mono uppercase tracking-widest text-[#999] hover:text-black transition-colors"
                          >
                            <span
                              className={`w-8 h-5 rounded-full relative transition-colors ${
                                surahTimerEnabled ? "bg-black" : "bg-[#e5e5e0]"
                              }`}
                            >
                              <span
                                className={`absolute top-0.5 w-4 h-4 bg-white rounded-full transition-all ${
                                  surahTimerEnabled ? "left-[14px]" : "left-0.5"
                                }`}
                              />
                            </span>
                            <span className="flex items-center gap-2">
                              <Clock size={12} />
                              Add timer (optional)
                            </span>
                          </button>
                        </div>

                        <AnimatePresence>
                          {surahTimerEnabled && (
                            <motion.div
                              initial={{ opacity: 0, height: 0 }}
                              animate={{ opacity: 1, height: "auto" }}
                              exit={{ opacity: 0, height: 0 }}
                              transition={{ duration: 0.25, ease: "easeOut" }}
                              className="overflow-hidden"
                            >
                              <div className="space-y-2 pt-4">
                                <div className="flex gap-2">
                                  {DURATIONS.map((d) => (
                                    <button
                                      key={d.value}
                                      onClick={() => {
                                        setTargetDuration(d.value);
                                        setCustomMinutes("");
                                      }}
                                      className={`flex-1 py-4 rounded-2xl text-lg font-bold transition-all duration-300 border ${
                                        targetDuration === d.value && !customMinutes
                                          ? "bg-black text-white border-black shadow-2xl shadow-black/20"
                                          : "bg-white text-[#666] border-[#e5e5e0] hover:border-black/20"
                                      }`}
                                    >
                                      {d.label}
                                    </button>
                                  ))}
                                </div>
                                <div
                                  className={`mt-2 flex items-center gap-3 rounded-2xl px-5 py-4 border transition-all duration-300 ${
                                    customMinutes
                                      ? "bg-black border-black shadow-2xl shadow-black/20"
                                      : "bg-white border-[#e5e5e0] hover:border-black/20"
                                  }`}
                                >
                                  <input
                                    type="number"
                                    min="1"
                                    max="120"
                                    placeholder="Custom duration"
                                    value={customMinutes}
                                    onChange={(e) => {
                                      const val = e.target.value;
                                      setCustomMinutes(val);
                                      if (val && Number(val) > 0) {
                                        setTargetDuration(Number(val) * 60);
                                      }
                                    }}
                                    className={`flex-1 bg-transparent outline-none text-lg font-bold placeholder:font-normal ${
                                      customMinutes
                                        ? "text-white placeholder:text-white/40"
                                        : "text-[#333] placeholder:text-[#aaa]"
                                    }`}
                                  />
                                  <span
                                    className={`text-sm font-bold uppercase tracking-widest ${
                                      customMinutes ? "text-white/50" : "text-[#aaa]"
                                    }`}
                                  >
                                    min
                                  </span>
                                </div>
                              </div>
                            </motion.div>
                          )}
                        </AnimatePresence>
                      </motion.div>
                    ) : (
                      <motion.div
                        key="duration-picker"
                        initial={{ opacity: 0, y: 12 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: -12 }}
                        transition={{ duration: 0.25, ease: "easeOut" }}
                        className="space-y-4"
                      >
                        <div className="flex items-center gap-2 text-[#999]">
                          <Clock size={14} />
                          <label className="text-xs font-mono uppercase tracking-widest">
                            How long?
                          </label>
                        </div>
                        <div className="flex gap-2">
                          {DURATIONS.map((d) => (
                            <button
                              key={d.value}
                              onClick={() => {
                                setTargetDuration(d.value);
                                setCustomMinutes("");
                              }}
                              className={`flex-1 py-4 rounded-2xl text-lg font-bold transition-all duration-300 border ${
                                targetDuration === d.value && !customMinutes
                                  ? "bg-black text-white border-black shadow-2xl shadow-black/20"
                                  : "bg-white text-[#666] border-[#e5e5e0] hover:border-black/20"
                              }`}
                            >
                              {d.label}
                            </button>
                          ))}
                        </div>
                        <div
                          className={`mt-2 flex items-center gap-3 rounded-2xl px-5 py-4 border transition-all duration-300 ${
                            customMinutes
                              ? "bg-black border-black shadow-2xl shadow-black/20"
                              : "bg-white border-[#e5e5e0] hover:border-black/20"
                          }`}
                        >
                          <input
                            type="number"
                            min="1"
                            max="120"
                            placeholder="Custom duration"
                            value={customMinutes}
                            onChange={(e) => {
                              const val = e.target.value;
                              setCustomMinutes(val);
                              if (val && Number(val) > 0) {
                                setTargetDuration(Number(val) * 60);
                              }
                            }}
                            className={`flex-1 bg-transparent outline-none text-lg font-bold placeholder:font-normal ${
                              customMinutes
                                ? "text-white placeholder:text-white/40"
                                : "text-[#333] placeholder:text-[#aaa]"
                            }`}
                          />
                          <span
                            className={`text-sm font-bold uppercase tracking-widest ${
                              customMinutes ? "text-white/50" : "text-[#aaa]"
                            }`}
                          >
                            min
                          </span>
                        </div>
                      </motion.div>
                    )}
                  </AnimatePresence>

                  <div className="space-y-4">
                    <div className="flex items-center gap-2 text-[#999]">
                      <Globe size={14} />
                      <label className="text-xs font-mono uppercase tracking-widest">
                        Who recites?
                      </label>
                    </div>
                    <div className="relative">
                      <select
                        value={reciterId}
                        onChange={(e) => setReciterId(Number(e.target.value))}
                        className="w-full bg-white border border-[#e5e5e0] rounded-2xl px-6 py-5 text-lg font-medium appearance-none cursor-pointer focus:outline-none focus:ring-4 focus:ring-black/5 transition-all"
                      >
                        {RECITERS.map((r) => (
                          <option key={r.id} value={r.id}>
                            {r.name}
                          </option>
                        ))}
                      </select>
                      <div className="absolute right-6 top-1/2 -translate-y-1/2 pointer-events-none text-[#999]">
                        <ChevronRight size={20} className="rotate-90" />
                      </div>
                    </div>
                  </div>
                </div>

                <button
                  onClick={startPlayback}
                  className="w-full bg-black text-white rounded-[2rem] py-8 text-2xl font-bold shadow-2xl shadow-black/30 hover:shadow-black/40 hover:-translate-y-1 active:translate-y-0 transition-all flex items-center justify-center gap-4 group"
                >
                  Start Listening
                  <Play
                    size={24}
                    fill="currentColor"
                    className="group-hover:scale-110 transition-transform"
                  />
                </button>
              </motion.div>
            )}

            {view === "playing" && (
              <motion.div
                key="playing"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="flex flex-col items-center text-center space-y-16 py-8"
              >
                {loading && !currentAyah ? (
                  <div className="space-y-12 w-full max-w-xl">
                    <motion.div
                      animate={{ opacity: [0.3, 0.6, 0.3] }}
                      transition={{ repeat: Infinity, duration: 1.5 }}
                      className="h-16 bg-black/5 rounded-3xl w-2/3 mx-auto"
                    />
                    <motion.div
                      animate={{ opacity: [0.3, 0.6, 0.3] }}
                      transition={{
                        repeat: Infinity,
                        duration: 1.5,
                        delay: 0.2,
                      }}
                      className="h-32 bg-black/5 rounded-3xl w-full"
                    />
                  </div>
                ) : (
                  currentAyah && (
                    <div className="space-y-16 w-full pb-40">
                      <AnimatePresence mode="wait">
                        <motion.div
                          key={currentAyah.key}
                          initial={{ opacity: 0, y: 20, filter: "blur(6px)" }}
                          animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
                          exit={{ opacity: 0, y: -20, filter: "blur(6px)" }}
                          transition={{ duration: 0.35, ease: "easeOut" }}
                          className="space-y-8"
                        >
                          <div className="flex items-center justify-center gap-4">
                            <div className="h-px w-8" style={{ backgroundColor: "var(--accent-gold-soft)" }} />
                            <p className="text-[10px] font-mono uppercase tracking-[0.3em] text-[#999]">
                              Surah {currentAyah.surahName} • Verse{" "}
                              {currentAyah.key}
                            </p>
                            <div className="h-px w-8" style={{ backgroundColor: "var(--accent-gold-soft)" }} />
                          </div>

                          <h3
                            className="text-5xl md:text-7xl font-serif leading-[1.4] md:leading-[1.4] text-center"
                            dir="rtl"
                          >
                            {currentAyah.text}
                          </h3>

                          <p className="text-xl md:text-3xl text-[#666] leading-relaxed italic max-w-2xl mx-auto font-light">
                            {currentAyah.translation}
                          </p>
                        </motion.div>
                      </AnimatePresence>

                    </div>
                  )
                )}

                {/* Gradient fade that masks scrolling content and Safari's
                    semi-transparent bottom chrome from bleeding into the dock */}
                <div className="playback-fade fixed left-0 right-0 bottom-0 z-40 pointer-events-none" />
                <div className="playback-dock fixed left-0 right-0 px-6 z-50">
                  <div className="max-w-screen-sm mx-auto bg-white/90 backdrop-blur-2xl border border-[#e5e5e0] rounded-[2.5rem] p-8 shadow-[0_32px_64px_-16px_rgba(0,0,0,0.1)] flex items-center justify-between gap-6">
                    <div className="flex items-center gap-6">
                      <button
                        onClick={() => setIsPlaying(!isPlaying)}
                        className="w-16 h-16 bg-black rounded-[1.5rem] flex items-center justify-center text-white shadow-xl shadow-black/20 hover:scale-105 active:scale-95 transition-all"
                      >
                        {isPlaying ? (
                          <Pause size={28} fill="currentColor" />
                        ) : (
                          <Play
                            size={28}
                            className="ml-1"
                            fill="currentColor"
                          />
                        )}
                      </button>
                      <div>
                        <p className="text-xl font-bold font-mono tracking-tighter">
                          {formatTime(elapsedTime)}
                        </p>
                        <p className="text-[10px] uppercase tracking-widest text-[#999] font-bold">
                          Progress
                        </p>
                      </div>
                    </div>

                    <div className="flex-1 max-w-[120px] text-right">
                      <p className="text-xl font-bold font-mono tracking-tighter">
                        {mode === "surah" && !surahTimerEnabled && currentAyah
                          ? `${currentAyah.key.split(":")[1]}/${chapters.find((c) => c.id === selectedSurah)?.verses_count || "?"}`
                          : formatTime(targetDuration)}
                      </p>
                      <p className="text-[10px] uppercase tracking-widest text-[#999] font-bold">
                        {mode === "surah" && !surahTimerEnabled ? "Verse" : "Duration"}
                      </p>
                    </div>
                  </div>

                  {/* Progress Bar under the capsule */}
                  <div className="max-w-screen-sm mx-auto mt-4 px-8">
                    <div className="h-1 w-full bg-[#f0f0eb] rounded-full overflow-hidden">
                      <motion.div
                        className="h-full rounded-full"
                        style={{
                          background: "linear-gradient(90deg, var(--accent-gold) 0%, var(--accent-gold-deep) 100%)",
                        }}
                        initial={{ width: 0 }}
                        animate={{
                          width: `${Math.min(100, mode === "surah" && !surahTimerEnabled && currentAyah
                            ? ((Number(currentAyah.key.split(":")[1])) / (chapters.find((c) => c.id === selectedSurah)?.verses_count || 1)) * 100
                            : (elapsedTime / targetDuration) * 100)}%`,
                        }}
                        transition={{ duration: 1 }}
                      />
                    </div>
                  </div>
                </div>
              </motion.div>
            )}

            {view === "finished" && (
              <motion.div
                key="finished"
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                className="text-center space-y-12"
              >
                <div className="relative inline-block">
                  <div
                    className="w-32 h-32 rounded-[2.5rem] flex items-center justify-center mx-auto shadow-2xl rotate-12"
                    style={{
                      background:
                        "linear-gradient(135deg, var(--accent-gold-deep) 0%, var(--accent-gold) 100%)",
                      boxShadow: "0 25px 50px -12px oklch(55% 0.12 65 / 0.35)",
                    }}
                  >
                    <Heart
                      size={56}
                      className="text-white"
                      fill="currentColor"
                    />
                  </div>
                  <motion.div
                    animate={{ scale: [1, 1.2, 1], opacity: [0.3, 0.7, 0.3] }}
                    transition={{ repeat: Infinity, duration: 2 }}
                    className="absolute -inset-4 border rounded-[3rem]"
                    style={{ borderColor: "var(--accent-gold-soft)" }}
                  />
                </div>

                <div className="space-y-4">
                  <h2 className="text-5xl font-serif font-bold italic leading-tight">
                    Barakallahu <br />
                    Feekum.
                  </h2>
                  <p className="text-[#666] text-xl max-w-sm mx-auto font-light leading-relaxed">
                    {mode === "surah" && surahTimerEnabled
                      ? `${targetDuration / 60} minutes with Surah ${chapters.find((c) => c.id === selectedSurah)?.name_simple || ""}. May Allah bless your consistency.`
                      : mode === "surah"
                      ? `Surah ${chapters.find((c) => c.id === selectedSurah)?.name_simple || ""}, beginning to end. May Allah bless your consistency.`
                      : `${targetDuration / 60} minutes with the words of Allah. May He bless your consistency.`}
                  </p>
                </div>

                <div className="flex flex-col gap-4 pt-12">
                  <button
                    onClick={() => setView("setup")}
                    className="bg-black text-white rounded-2xl py-6 text-xl font-bold shadow-2xl shadow-black/20 hover:scale-[1.02] active:scale-98 transition-all"
                  >
                    New Session
                  </button>
                  <button
                    onClick={handleRepeat}
                    className="text-[#666] py-4 text-sm font-bold uppercase tracking-widest hover:text-black transition-colors"
                  >
                    Repeat
                  </button>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </main>


        {error && (
          <div className="fixed top-24 left-1/2 -translate-x-1/2 bg-red-50 text-red-600 px-6 py-3 rounded-2xl text-sm font-bold border border-red-100 flex items-center gap-3 shadow-xl z-[100]">
            <span className="w-2 h-2 bg-red-600 rounded-full status-pulse" />
            <span>{error}</span>
            <button
              onClick={() => setError(null)}
              className="ml-2 hover:opacity-50"
            >
              x
            </button>
          </div>
        )}
      </div>

      <style jsx global>{`
        @import url('https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400;0,700;1,400;1,700&family=Inter:wght@300;400;500;600;700&display=swap');

        @font-face {
          font-family: 'Arsenica';
          src: url('/arsenica-regular.ttf') format('truetype');
          font-weight: 400;
          font-style: normal;
          font-display: swap;
        }
        @font-face {
          font-family: 'Arsenica';
          src: url('/arsenica-bold.ttf') format('truetype');
          font-weight: 700;
          font-style: normal;
          font-display: swap;
        }
        @font-face {
          font-family: 'Resolide Serif';
          src: url('/resolide-serif.otf') format('opentype');
          font-weight: normal;
          font-style: normal;
          font-display: swap;
        }

        .font-resolide {
          font-family: 'Arsenica', 'Resolide Serif', 'Playfair Display', serif;
        }

        :root {
          /* Warm amber/ochre — aged manuscript illumination gold */
          --accent-gold: oklch(72% 0.11 75);
          --accent-gold-soft: oklch(86% 0.06 75);
          --accent-gold-deep: oklch(55% 0.12 65);
          /* Muted sage — traditional Islamic heritage green */
          --accent-sage: oklch(50% 0.06 155);
          --accent-sage-soft: oklch(90% 0.02 150);
          /* Warm tinted neutrals */
          --surface-warm: oklch(97% 0.008 80);
          --border-warm: oklch(88% 0.015 75);
        }

        /* Lock html and body from scrolling so iOS rubber-band overscroll
           never exposes them. All scrolling happens inside .app-shell instead. */
        html, body {
          height: 100%;
          overflow: hidden;
          background-color: oklch(97% 0.008 80);
          overscroll-behavior: none;
        }

        body {
          color: #1a1a1a;
          -webkit-font-smoothing: antialiased;
        }

        /* App shell is now the scroll container. Overscroll is contained
           within it, so any bounce stays inside the styled area. */
        .app-shell {
          position: fixed;
          inset: 0;
          overflow-y: auto;
          overscroll-behavior-y: contain;
          scroll-behavior: smooth;
          -webkit-overflow-scrolling: touch;
        }

        .app-container {
          min-height: 100%;
        }

        /* Playback dock — sits above iOS home indicator via safe-area inset. */
        .playback-dock {
          bottom: calc(3rem + env(safe-area-inset-bottom, 0px));
        }

        /* Gradient fade behind the dock.
           Extends to the very bottom edge of the viewport (under Safari's
           translucent bottom toolbar) so scrolling content and dock shadows
           don't bleed awkwardly against the browser chrome. */
        .playback-fade {
          height: calc(12rem + env(safe-area-inset-bottom, 0px));
          background: linear-gradient(
            to bottom,
            oklch(97% 0.008 80 / 0) 0%,
            oklch(97% 0.008 80 / 0.7) 40%,
            oklch(97% 0.008 80 / 1) 70%,
            oklch(97% 0.008 80 / 1) 100%
          );
        }

        ::selection {
          background-color: var(--accent-gold-soft);
          color: var(--accent-gold-deep);
        }

        .font-serif {
          font-family: 'Playfair Display', serif;
        }

        .font-inter {
          font-family: 'Inter', sans-serif;
        }

        .status-pulse {
          animation: status-pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
        }

        @keyframes status-pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: .5; }
        }

        /* Hide number input spinners */
        input[type="number"]::-webkit-inner-spin-button,
        input[type="number"]::-webkit-outer-spin-button {
          -webkit-appearance: none;
          margin: 0;
        }
        input[type="number"] {
          -moz-appearance: textfield;
        }

        /* Reduce motion for users who prefer it */
        @media (prefers-reduced-motion: reduce) {
          *, *::before, *::after {
            animation-duration: 0.01ms !important;
            animation-iteration-count: 1 !important;
            transition-duration: 0.01ms !important;
          }
        }

        /* Custom scrollbar — slim black thumb with a single gold hair down the center */
        * {
          scrollbar-width: thin;
          scrollbar-color: #1a1a1a transparent;
        }
        ::-webkit-scrollbar {
          width: 8px;
          height: 8px;
        }
        ::-webkit-scrollbar-track {
          background: transparent;
        }
        ::-webkit-scrollbar-thumb {
          /* Black capsule with a thin amber hairline running down its middle.
             Large transparent top/bottom border makes the visible thumb shorter. */
          background:
            linear-gradient(
              90deg,
              #1a1a1a 0%,
              #1a1a1a 45%,
              var(--accent-gold) 45%,
              var(--accent-gold) 55%,
              #1a1a1a 55%,
              #1a1a1a 100%
            );
          border-radius: 999px;
          border: 2px solid transparent;
          background-clip: padding-box;
          transition: all 0.2s ease;
        }
        ::-webkit-scrollbar-thumb:hover {
          background:
            linear-gradient(
              90deg,
              #000 0%,
              #000 40%,
              var(--accent-gold) 40%,
              var(--accent-gold) 60%,
              #000 60%,
              #000 100%
            );
          background-clip: padding-box;
          box-shadow: 0 0 6px oklch(55% 0.12 65 / 0.3);
        }
        ::-webkit-scrollbar-corner {
          background: transparent;
        }
      `}</style>
    </div>
  );
}
