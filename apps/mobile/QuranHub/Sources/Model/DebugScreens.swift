import Foundation

/// Screenshot-only verification hook (QH_SCREEN env). No effect in normal runs;
/// lets a build be launched straight into a given view for visual parity checks.
enum DebugScreens {
    static func apply(_ model: AppModel) {
        guard let screen = ProcessInfo.processInfo.environment["QH_SCREEN"] else { return }

        func ayah(_ surah: Int, _ n: Int) -> CurrentAyah {
            let v = QuranText.verses(surah).first { $0.n == n }
            let words = (v?.ar ?? "").split(separator: " ").enumerated().map {
                Word(position: $0.offset + 1, text: String($0.element), translation: "", transliteration: "")
            }
            return CurrentAyah(key: "\(surah):\(n)", text: v?.ar ?? "", translation: v?.en ?? "",
                               surahName: chapter(surah)?.nameSimple ?? "", segments: [], words: words)
        }

        switch screen {
        case "playing":
            model.view = .playing
            model.currentAyah = ayah(1, 2)
            model.elapsedTime = 73
        case "playing-surah":
            model.mode = "surah"; model.selectedSurah = 1
            model.view = .playing
            model.currentAyah = ayah(1, 2)
        case "finished":
            model.view = .finished
            model.streak = Streak(count: 4, lastDate: "2026-05-18")
        case "settings":
            model.showSettings = true
        case "bookmarks":
            let v = QuranText.verses(1).first { $0.n == 1 }
            model.savedVerses = [SavedVerse(surah: 1, surahName: "Al-Fatihah", verseKey: "1:1",
                                            text: v?.ar ?? "", translation: v?.en ?? "",
                                            savedAt: Date().timeIntervalSince1970 * 1000)]
            model.showBookmarks = true
        case "surah":
            model.mode = "surah"
        default:
            break
        }
    }
}
