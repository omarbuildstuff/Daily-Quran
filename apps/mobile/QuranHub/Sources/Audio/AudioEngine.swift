import Foundation
import AVFoundation
import MediaPlayer
import UIKit

/// Owns AVPlayer and ports every playback rule from apps/web/src/app/page.jsx:
/// active-verse tracking, karaoke word sync, memorization loop/stop, timer
/// auto-stop, random-mode prefetch + seamless next, streak/history/bookmark
/// side-effects, plus native background audio + Now Playing.
@MainActor
final class AudioEngine {
    private let model: AppModel
    private let player = AVPlayer()

    private var surahData: SurahData?
    private var nextSurahData: SurahData?
    private var playedSurahs: [Int] = []
    private var lastTrackedSurah: Int?

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var elapsedTimer: Timer?

    private let utcDay: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(model: AppModel) {
        self.model = model
        player.automaticallyWaitsToMinimizeStalling = true
        addPeriodicObserver()
        setupRemoteCommands()
    }

    private func nowMs() -> Double { Date().timeIntervalSince1970 * 1000 }

    // MARK: - Random pool (verbatim pickNextRandomSurah)

    private func pickNextRandomSurah() -> Int {
        let pool: [Int]
        if model.moodEnabled {
            let m = MOODS.first { $0.id == model.selectedMood }
            pool = (m?.surahs.isEmpty == false) ? m!.surahs : [1]
        } else {
            pool = Array(1...114)
        }
        let unplayed = pool.filter { !playedSurahs.contains($0) }
        let source = unplayed.isEmpty ? pool : unplayed
        if unplayed.isEmpty { playedSurahs = [] }
        let picked = source[Int.random(in: 0..<source.count)]
        playedSurahs.append(picked)
        return picked
    }

    private func prefetchRandomSurah() {
        Task {
            do {
                let nextId = pickNextRandomSurah()
                nextSurahData = try await QuranAPI.fetchSurahData(surahId: nextId, reciterId: model.reciterId)
            } catch {
                nextSurahData = nil
            }
        }
    }

    // MARK: - Load & play

    private func loadAndPlaySurah(_ surahId: Int, preloaded: SurahData? = nil) {
        model.loading = true
        model.errorMessage = nil
        Task {
            do {
                let data: SurahData
                if let preloaded { data = preloaded }
                else { data = try await QuranAPI.fetchSurahData(surahId: surahId, reciterId: model.reciterId) }
                surahData = data

                let initialVerse: Verse?
                if model.mode == "surah" && model.memorizationEnabled {
                    initialVerse = data.verses.first { $0.num == model.memStartVerse } ?? data.verses.first
                } else {
                    initialVerse = data.verses.first
                }
                if let v = initialVerse { setCurrentAyah(v, surahName: data.surahName) }

                attachItem(url: data.audioUrl)
                if model.mode == "surah", model.memorizationEnabled, let v = initialVerse {
                    seek(ms: v.startMs)
                }
                player.play()
                model.loading = false
                updateNowPlaying()

                if model.mode == "random" { prefetchRandomSurah() }
            } catch {
                model.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                model.loading = false
            }
        }
    }

    private func attachItem(url: String) {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        let item = AVPlayerItem(url: URL(string: url)!)
        player.replaceCurrentItem(with: item)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleSurahEnded() }
        }
    }

    private func seek(ms: Double) {
        player.seek(to: CMTime(seconds: ms / 1000, preferredTimescale: 1000),
                    toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: - Ended (verbatim handleSurahEnded)

    private func handleSurahEnded() {
        if model.mode == "surah" {
            if model.memorizationEnabled && model.memRepeat,
               let sd = surahData, let startV = sd.verses.first(where: { $0.num == model.memStartVerse }) {
                seek(ms: startV.startMs)
                player.play()
                return
            }
            finish()
            return
        }
        let elapsed = (nowMs() - model.startTime) / 1000
        if elapsed >= Double(model.targetDuration) { finish(); return }
        if let preloaded = nextSurahData {
            nextSurahData = nil
            loadAndPlaySurah(preloaded.surah, preloaded: preloaded)
        } else {
            loadAndPlaySurah(pickNextRandomSurah())
        }
    }

    private func finish() {
        player.pause()
        model.view = .finished
        model.isPlaying = false
        updateNowPlaying()
    }

    // MARK: - Public controls

    func startPlayback() {
        surahData = nil
        nextSurahData = nil
        playedSurahs = []
        lastTrackedSurah = nil
        let startSurah = model.mode == "surah" ? model.selectedSurah : pickNextRandomSurah()
        model.elapsedTime = 0
        model.startTime = nowMs()
        model.view = .playing
        model.isPlaying = true
        startElapsedTimer()
        loadAndPlaySurah(startSurah)
    }

    func handleRepeat() { startPlayback() }

    func handleEndSession() {
        model.view = .setup
        model.isPlaying = false
        player.pause()
        player.replaceCurrentItem(with: nil)
        surahData = nil
        nextSurahData = nil
        model.currentAyah = nil
        stopElapsedTimer()
        updateNowPlaying()
    }

    func setPlaying(_ playing: Bool) {
        model.isPlaying = playing
        if playing { player.play() } else { player.pause() }
        if playing { startElapsedTimer() } else { stopElapsedTimer() }
        updateNowPlaying()
    }

    func handleResume() {
        guard let ls = model.lastSession else { return }
        model.showResumePrompt = false
        model.mode = "surah"
        model.selectedSurah = ls.surah
        surahData = nil
        nextSurahData = nil
        playedSurahs = []
        lastTrackedSurah = nil
        model.elapsedTime = 0
        model.startTime = nowMs()
        model.view = .playing
        model.isPlaying = true
        model.loading = true
        model.errorMessage = nil
        startElapsedTimer()
        Task {
            do {
                let data = try await QuranAPI.fetchSurahData(surahId: ls.surah, reciterId: model.reciterId)
                surahData = data
                let verseNum = Int(ls.verseKey.split(separator: ":").last ?? "1") ?? 1
                let startV = data.verses.first { $0.num == verseNum } ?? data.verses.first
                if let v = startV { setCurrentAyah(v, surahName: data.surahName) }
                attachItem(url: data.audioUrl)
                if let v = startV { seek(ms: v.startMs) }
                player.play()
                model.loading = false
                updateNowPlaying()
            } catch {
                model.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                model.loading = false
            }
        }
    }

    func dismissResume() {
        model.showResumePrompt = false
        model.lastSession = nil
    }

    // MARK: - Save verse (toggleSaveCurrentVerse)

    func toggleSaveCurrentVerse() {
        guard let a = model.currentAyah, let sd = surahData else { return }
        if model.savedVerses.contains(where: { $0.verseKey == a.key }) {
            model.savedVerses.removeAll { $0.verseKey == a.key }
        } else {
            model.savedVerses.insert(
                SavedVerse(surah: sd.surah, surahName: a.surahName, verseKey: a.key,
                           text: a.text, translation: a.translation, savedAt: nowMs()),
                at: 0)
        }
    }

    // MARK: - Surah-mode scrub (verse-based seek)

    func scrubToRatio(_ r: Double) {
        guard let sd = surahData, !sd.verses.isEmpty else { return }
        let idx = min(sd.verses.count - 1, Int(r * Double(sd.verses.count)))
        seek(ms: sd.verses[idx].startMs)
    }

    // MARK: - Periodic time observer (updateCurrentVerse + handleTimeUpdate)

    private func addPeriodicObserver() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        guard let sd = surahData, model.view == .playing else { return }
        let currentMs = player.currentTime().seconds * 1000
        guard currentMs.isFinite else { return }

        let active = sd.verses.first { currentMs >= $0.startMs && currentMs < $0.endMs } ?? sd.verses.last
        guard let active else { return }

        if model.currentAyah?.key != active.key {
            setCurrentAyah(active, surahName: sd.surahName)
        }

        // Karaoke word highlight
        if !active.segments.isEmpty {
            let seg = active.segments.first { $0.count >= 3 && currentMs >= Double($0[1]) && currentMs < Double($0[2]) }
            let idx = seg?.first ?? 0
            if model.currentWordIdx != idx { model.currentWordIdx = idx }
        } else if model.currentWordIdx != 0 {
            model.currentWordIdx = 0
        }

        // Memorization — loop/stop at range end (takes priority over timer)
        if model.mode == "surah" && model.memorizationEnabled {
            guard let startV = sd.verses.first(where: { $0.num == model.memStartVerse }),
                  let endV = sd.verses.first(where: { $0.num == model.memEndVerse }) else { return }
            if currentMs >= endV.endMs - 60 {
                if model.memRepeat { seek(ms: startV.startMs) }
                else { finish() }
            }
            return
        }

        // Timer auto-stop (waits for end of current verse, ~200ms)
        let timerActive = model.autoStopTimer &&
            (model.mode == "random" || (model.mode == "surah" && model.surahTimerEnabled))
        if timerActive {
            let elapsed = (nowMs() - model.startTime) / 1000
            if elapsed >= Double(model.targetDuration) {
                if let a = sd.verses.first(where: { currentMs >= $0.startMs && currentMs < $0.endMs }),
                   a.endMs - currentMs <= 200 {
                    finish()
                }
            }
        }
    }

    private func setCurrentAyah(_ v: Verse, surahName: String) {
        model.currentAyah = CurrentAyah(key: v.key, text: v.text, translation: v.translation,
                                        surahName: surahName, segments: v.segments, words: v.words)
        model.hoveredWordPos = nil
        onVerseChanged()
        updateNowPlaying()
    }

    // MARK: - Verse-change side effects (the 3 PWA effects)

    private func onVerseChanged() {
        guard model.view == .playing, let a = model.currentAyah, let sd = surahData else { return }

        // Bookmark last session
        model.lastSession = LastSession(surah: sd.surah, surahName: sd.surahName,
                                        verseKey: a.key, mode: model.mode, savedAt: nowMs())

        // Daily streak
        let today = utcDay.string(from: Date())
        if model.streak.lastDate != today {
            let yesterday = utcDay.string(from: Date().addingTimeInterval(-86400))
            let continued = model.streak.lastDate == yesterday
            model.streak = Streak(count: continued ? model.streak.count + 1 : 1, lastDate: today)
        }

        // Per-surah listen history (dedupe per surah load)
        if lastTrackedSurah != sd.surah {
            lastTrackedSurah = sd.surah
            let key = String(sd.surah)
            let prev = model.listenedSurahs[key]
            model.listenedSurahs[key] = ListenedEntry(count: (prev?.count ?? 0) + 1, lastPlayed: nowMs())
        }
    }

    // MARK: - Elapsed timer (1s)

    private func startElapsedTimer() {
        stopElapsedTimer()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.model.view == .playing && self.model.isPlaying {
                    self.model.elapsedTime += 1
                }
            }
        }
    }

    private func stopElapsedTimer() { elapsedTimer?.invalidate(); elapsedTimer = nil }

    // MARK: - Now Playing / remote commands (native enhancement of wake-lock)

    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.setPlaying(true) }; return .success
        }
        c.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.setPlaying(false) }; return .success
        }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self.map { $0.setPlaying(!$0.model.isPlaying) } }; return .success
        }
    }

    private func updateNowPlaying() {
        var info: [String: Any] = [:]
        if let a = model.currentAyah {
            info[MPMediaItemPropertyTitle] = "Surah \(a.surahName)"
            info[MPMediaItemPropertyArtist] = RECITERS.first { $0.id == model.reciterId }?.name ?? "Quran Hub"
            info[MPNowPlayingInfoPropertyPlaybackRate] = model.isPlaying ? 1.0 : 0.0
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info.isEmpty ? nil : info
        UIApplication.shared.isIdleTimerDisabled = (model.view == .playing && model.isPlaying)
    }
}
