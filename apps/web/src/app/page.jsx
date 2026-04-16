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

  const audioARef = useRef(null);
  const audioBRef = useRef(null);
  const activeAudioRef = useRef(null); // direct pointer to whichever DOM element is playing
  const timerRef = useRef(null);
  const currentAyahKeyRef = useRef({ surah: 1, ayah: 1 });
  const prefetchedRef = useRef(null);
  const transitioningRef = useRef(false); // prevents double-firing during crossover

  const getInactiveAudio = useCallback(() => {
    if (activeAudioRef.current === audioARef.current) return audioBRef.current;
    return audioARef.current;
  }, []);

  const getNextAyahKey = useCallback((surah, ayah) => {
    const currentChapter = chapters.find((c) => c.id === surah);
    let nextSurah = surah;
    let nextAyah = ayah + 1;
    if (nextAyah > currentChapter.verses_count) {
      nextSurah = surah + 1;
      nextAyah = 1;
      if (nextSurah > 114) nextSurah = 1;
    }
    return { surah: nextSurah, ayah: nextAyah };
  }, []);

  const fetchAyahRaw = useCallback(
    async (surah, ayah) => {
      const ayahKey = `${surah}:${ayah}`;

      const [verseResponse, translationResponse, audioResponse] =
        await Promise.all([
          fetch(
            `https://api.quran.com/api/v4/verses/by_key/${ayahKey}?fields=text_uthmani`,
          ),
          fetch(
            `https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/eng-mustafakhattaba/${surah}/${ayah}.json`,
          ),
          fetch(
            `https://api.quran.com/api/v4/recitations/${reciterId}/by_ayah/${ayahKey}`,
          ),
        ]);

      if (!verseResponse.ok) throw new Error(`Verse API error: ${verseResponse.status}`);
      if (!audioResponse.ok) throw new Error(`Audio API error: ${audioResponse.status}`);

      const [verseData, translationData, audioData] = await Promise.all([
        verseResponse.json(),
        translationResponse.ok ? translationResponse.json() : null,
        audioResponse.json(),
      ]);

      if (!verseData.verse) throw new Error("Verse data not found");
      if (!audioData.audio_files || audioData.audio_files.length === 0)
        throw new Error("Audio not found for this reciter");

      const translation =
        translationData?.text
          ? translationData.text
          : "Translation not available";

      const audioUrl = audioData.audio_files[0].url;

      return {
        key: ayahKey,
        text: verseData.verse.text_uthmani,
        translation: translation
          .replace(/<sup[^>]*>.*?<\/sup>/gi, "")
          .replace(/<[^>]*>/g, ""),
        audioUrl: audioUrl.startsWith("http")
          ? audioUrl
          : `https://verses.quran.com/${audioUrl}`,
        surahName:
          chapters.find((c) => c.id === surah)?.name_simple ||
          `Surah ${surah}`,
      };
    },
    [reciterId],
  );

  // Prefetch next verse data AND preload audio file into inactive element
  const prefetchNext = useCallback(
    (surah, ayah) => {
      const next = getNextAyahKey(surah, ayah);
      const promise = fetchAyahRaw(next.surah, next.ayah)
        .then((data) => {
          // Preload audio file into the inactive audio element
          const preloadEl = getInactiveAudio();
          if (preloadEl && data) {
            preloadEl.src = data.audioUrl;
            preloadEl.load();
          }
          return data;
        })
        .catch(() => null);
      prefetchedRef.current = { key: next, promise };
    },
    [getNextAyahKey, fetchAyahRaw, getInactiveAudio],
  );

  const playAyah = useCallback((data, targetElement) => {
    setCurrentAyah(data);
    setLoading(false);
    const el = targetElement || activeAudioRef.current;
    if (el) {
      if (el.src !== data.audioUrl) {
        el.src = data.audioUrl;
      }
      el.play().catch((e) => console.error("Playback error:", e));
    }
  }, []);

  const fetchAyahData = useCallback(
    async (surah, ayah) => {
      setLoading(true);
      setError(null);
      try {
        const data = await fetchAyahRaw(surah, ayah);
        playAyah(data);
        prefetchNext(surah, ayah);
      } catch (err) {
        console.error("Fetch error:", err);
        setError(err.message);
        setLoading(false);
      }
    },
    [fetchAyahRaw, playAyah, prefetchNext],
  );

  // Called either from timeupdate (early crossover) or onEnded (fallback)
  const handleNextAyah = useCallback((fromTimeUpdate = false) => {
    if (transitioningRef.current) return;
    transitioningRef.current = true;

    const { surah, ayah } = currentAyahKeyRef.current;

    // In surah mode, stop at the end of the surah
    if (mode === "surah") {
      const currentChapter = chapters.find((c) => c.id === surah);
      if (ayah >= currentChapter.verses_count) {
        transitioningRef.current = false;
        setView("finished");
        setIsPlaying(false);
        return;
      }
    }

    const next = getNextAyahKey(surah, ayah);
    currentAyahKeyRef.current = next;

    // In random mode, stop after the target duration
    if (mode === "random") {
      const now = Date.now();
      if ((now - startTime) / 1000 >= targetDuration) {
        transitioningRef.current = false;
        setView("finished");
        setIsPlaying(false);
        return;
      }
    }

    const pf = prefetchedRef.current;
    if (pf && pf.key.surah === next.surah && pf.key.ayah === next.ayah) {
      // If promise is already settled, Promise.resolve wraps it so .then fires synchronously
      // in the microtask queue — still fast, but we avoid blocking
      Promise.resolve(pf.promise).then((data) => {
        transitioningRef.current = false;
        if (data) {
          const preloadedEl = getInactiveAudio();
          // Silence the outgoing element immediately so there's no overlap bleed
          const outgoing = activeAudioRef.current;
          activeAudioRef.current = preloadedEl;
          playAyah(data, preloadedEl);
          // After playback starts on the new element, stop the old one cleanly
          if (outgoing && outgoing !== preloadedEl) {
            outgoing.pause();
            outgoing.currentTime = 0;
          }
          prefetchNext(next.surah, next.ayah);
        } else {
          fetchAyahData(next.surah, next.ayah);
        }
      });
    } else {
      transitioningRef.current = false;
      fetchAyahData(next.surah, next.ayah);
    }
  }, [mode, startTime, targetDuration, getNextAyahKey, getInactiveAudio, playAyah, prefetchNext, fetchAyahData]);

  // timeupdate handler: fires ~4x/second, triggers crossover ~150ms before end.
  // Both audio elements have this wired — guard so only the ACTIVE element triggers.
  const handleTimeUpdate = useCallback((e) => {
    const el = activeAudioRef.current;
    if (!el || e.target !== el) return; // ignore events from the inactive (preloading) element
    if (!el.duration || isNaN(el.duration)) return;
    if (transitioningRef.current) return;
    const remaining = el.duration - el.currentTime;
    if (remaining <= 0.15 && remaining > 0) {
      handleNextAyah(true);
    }
  }, [handleNextAyah]);

  const startPlayback = () => {
    const startSurah = mode === "surah" ? selectedSurah : Math.floor(Math.random() * 114) + 1;
    const startAyah = 1;
    currentAyahKeyRef.current = { surah: startSurah, ayah: startAyah };
    prefetchedRef.current = null;
    activeAudioRef.current = audioARef.current;

    setElapsedTime(0);
    setStartTime(Date.now());
    setView("playing");
    setIsPlaying(true);
    fetchAyahData(startSurah, startAyah);
  };

  useEffect(() => {
    const el = activeAudioRef.current;
    if (el) {
      if (isPlaying) {
        el.play().catch((e) => console.error("Playback error:", e));
      } else {
        el.pause();
      }
    }
  }, [isPlaying]);

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

  const formatTime = (seconds) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, "0")}`;
  };

  return (
    <div className="min-h-screen text-[#1a1a1a] font-inter selection:bg-black selection:text-white">
      <audio ref={audioARef} onEnded={() => handleNextAyah(false)} onTimeUpdate={handleTimeUpdate} preload="auto" />
      <audio ref={audioBRef} onEnded={() => handleNextAyah(false)} onTimeUpdate={handleTimeUpdate} preload="auto" />
      <div className="max-w-screen-md mx-auto min-h-screen flex flex-col p-6 md:p-12">
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
              onClick={() => {
                setView("setup");
                setIsPlaying(false);
                [audioARef, audioBRef].forEach((ref) => {
                  if (ref.current) {
                    ref.current.pause();
                    ref.current.removeAttribute("src");
                    ref.current.load();
                  }
                });
                activeAudioRef.current = null;
                prefetchedRef.current = null;
              }}
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
                    className="h-1 bg-black"
                  />
                  <h2 className="text-5xl md:text-7xl font-serif font-bold italic leading-[1.1] tracking-tighter">
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
                      Random Surah
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
                            <div className="h-px w-8 bg-[#e5e5e0]" />
                            <p className="text-[10px] font-mono uppercase tracking-[0.3em] text-[#999]">
                              Surah {currentAyah.surahName} • Verse{" "}
                              {currentAyah.key}
                            </p>
                            <div className="h-px w-8 bg-[#e5e5e0]" />
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

                <div className="fixed bottom-12 left-0 right-0 px-6 z-50">
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
                        {mode === "surah" && currentAyah
                          ? `${currentAyah.key.split(":")[1]}/${chapters.find((c) => c.id === selectedSurah)?.verses_count || "?"}`
                          : formatTime(targetDuration)}
                      </p>
                      <p className="text-[10px] uppercase tracking-widest text-[#999] font-bold">
                        {mode === "surah" ? "Verse" : "Duration"}
                      </p>
                    </div>
                  </div>

                  {/* Progress Bar under the capsule */}
                  <div className="max-w-screen-sm mx-auto mt-4 px-8">
                    <div className="h-1 w-full bg-[#f0f0eb] rounded-full overflow-hidden">
                      <motion.div
                        className="h-full bg-black rounded-full"
                        initial={{ width: 0 }}
                        animate={{
                          width: `${Math.min(100, mode === "surah" && currentAyah
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
                  <div className="w-32 h-32 bg-black rounded-[2.5rem] flex items-center justify-center mx-auto shadow-2xl shadow-black/20 rotate-12">
                    <Heart
                      size={56}
                      className="text-white"
                      fill="currentColor"
                    />
                  </div>
                  <motion.div
                    animate={{ scale: [1, 1.2, 1], opacity: [0.5, 1, 0.5] }}
                    transition={{ repeat: Infinity, duration: 2 }}
                    className="absolute -inset-4 border border-black/10 rounded-[3rem]"
                  />
                </div>

                <div className="space-y-4">
                  <h2 className="text-5xl font-serif font-bold italic leading-tight">
                    Barakallahu <br />
                    Feekum.
                  </h2>
                  <p className="text-[#666] text-xl max-w-sm mx-auto font-light leading-relaxed">
                    {mode === "surah"
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
                    onClick={startPlayback}
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
              ×
            </button>
          </div>
        )}
      </div>

      <style jsx global>{`
        @import url('https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400;0,700;1,400;1,700&family=Inter:wght@300;400;500;600;700&display=swap');
        
        body {
          background-color: #fafaf5;
          color: #1a1a1a;
          -webkit-font-smoothing: antialiased;
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

        /* Hide scrollbar but keep functionality */
        ::-webkit-scrollbar {
          display: none;
        }
      `}</style>
    </div>
  );
}
