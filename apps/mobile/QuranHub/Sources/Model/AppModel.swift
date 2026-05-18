import Foundation
import Observation

@Observable
final class AppModel {

    // MARK: Persisted (quranaday.v1.*) — defaults match the PWA exactly

    var reciterId: Int            { didSet { Store.set("reciterId", reciterId) } }
    var targetDuration: Int       { didSet { Store.set("targetDuration", targetDuration) } }
    var mode: String              { didSet { Store.set("mode", mode) } }
    var selectedSurah: Int        { didSet { Store.set("selectedSurah", selectedSurah) } }
    var selectedMood: String      { didSet { Store.set("selectedMood", selectedMood) } }
    var moodEnabled: Bool         { didSet { Store.set("moodEnabled", moodEnabled) } }
    var surahTimerEnabled: Bool   { didSet { Store.set("surahTimerEnabled", surahTimerEnabled) } }
    var memorizationEnabled: Bool { didSet { Store.set("memorizationEnabled", memorizationEnabled) } }
    var memStartVerse: Int        { didSet { Store.set("memStartVerse", memStartVerse) } }
    var memEndVerse: Int          { didSet { Store.set("memEndVerse", memEndVerse) } }
    var memRepeat: Bool           { didSet { Store.set("memRepeat", memRepeat) } }
    var autoStopTimer: Bool       { didSet { Store.set("autoStopTimer", autoStopTimer) } }
    var languageMode: String      { didSet { Store.set("languageMode", languageMode) } }
    var autoFocus: String         { didSet { Store.set("autoFocus", autoFocus) } }
    var karaokeEnabled: Bool      { didSet { Store.set("karaokeEnabled", karaokeEnabled) } }
    var wordTooltipsEnabled: Bool { didSet { Store.set("wordTooltipsEnabled", wordTooltipsEnabled) } }
    var karaokeColor: String      { didSet { Store.set("karaokeColor", karaokeColor) } }
    var lastSession: LastSession? { didSet { Store.set("lastSession", lastSession) } }
    var streak: Streak            { didSet { Store.set("streak", streak) } }
    var listenedSurahs: [String: ListenedEntry] { didSet { Store.set("listenedSurahs", listenedSurahs) } }
    var savedVerses: [SavedVerse] { didSet { Store.set("savedVerses", savedVerses) } }
    var reminderEnabled: Bool     { didSet { Store.set("reminderEnabled", reminderEnabled) } }
    var reminderTime: String      { didSet { Store.set("reminderTime", reminderTime) } }

    // MARK: Session-only (not persisted)

    var view: AppView = .setup
    var currentAyah: CurrentAyah?
    var currentWordIdx: Int = 0
    var hoveredWordPos: Int?
    var isPlaying: Bool = false
    var elapsedTime: Int = 0
    var startTime: Double = 0          // ms epoch
    var loading: Bool = false
    var customMinutes: String = ""
    var errorMessage: String?
    var showSettings = false
    var showResumePrompt = false
    var showReminderBanner = false
    var showBookmarks = false

    /// Auto-scroll hook (RootView wires the ScrollViewReader proxy here).
    @ObservationIgnored var scrollTo: ((String) -> Void)?

    init() {
        reciterId            = Store.get("reciterId", 7)
        targetDuration       = Store.get("targetDuration", 300)
        mode                 = Store.get("mode", "random")
        selectedSurah        = Store.get("selectedSurah", 1)
        selectedMood         = Store.get("selectedMood", "fear")
        moodEnabled          = Store.get("moodEnabled", false)
        surahTimerEnabled    = Store.get("surahTimerEnabled", false)
        memorizationEnabled  = Store.get("memorizationEnabled", false)
        memStartVerse        = Store.get("memStartVerse", 1)
        memEndVerse          = Store.get("memEndVerse", 1)
        memRepeat            = Store.get("memRepeat", false)
        autoStopTimer        = Store.get("autoStopTimer", true)
        languageMode         = Store.get("languageMode", "both")
        autoFocus            = Store.get("autoFocus", "arabic")
        karaokeEnabled       = Store.get("karaokeEnabled", false)
        wordTooltipsEnabled  = Store.get("wordTooltipsEnabled", false)
        karaokeColor         = Store.get("karaokeColor", "gold")
        lastSession          = Store.get("lastSession", LastSession?.none)
        streak               = Store.get("streak", Streak(count: 0, lastDate: nil))
        listenedSurahs       = Store.get("listenedSurahs", [:])
        savedVerses          = Store.get("savedVerses", [])
        reminderEnabled      = Store.get("reminderEnabled", false)
        reminderTime         = Store.get("reminderTime", "07:00")
    }

    // MARK: Derived

    var isCurrentVerseSaved: Bool {
        guard let a = currentAyah else { return false }
        return savedVerses.contains { $0.verseKey == a.key }
    }

    func versesCount(_ surahId: Int) -> Int { chapter(surahId)?.versesCount ?? 1 }
}
