import Foundation

// MARK: - Static catalog types

struct Chapter: Identifiable, Hashable {
    let id: Int
    let nameSimple: String
    let nameArabic: String
    let versesCount: Int
}

struct Reciter: Identifiable, Hashable {
    let id: Int
    let name: String
}

struct Mood: Identifiable, Hashable {
    let id: String
    let label: String
    let emoji: String
    let surahs: [Int]
}

struct DurationOption: Identifiable, Hashable {
    var id: Int { value }
    let label: String
    let value: Int   // seconds
}

// MARK: - Verse / surah runtime data

/// Per-word data for the Arabic line (karaoke highlight + translation tooltip).
struct Word: Identifiable, Hashable {
    var id: Int { position }
    let position: Int          // 1-based; matches segment word index
    let text: String
    let translation: String
    let transliteration: String
}

/// One verse with audio timing + per-word data merged in.
struct Verse: Identifiable, Hashable {
    var id: String { key }
    let num: Int
    let key: String            // "surah:ayah"
    let text: String           // Uthmani Arabic
    let translation: String    // Khattab English
    var startMs: Double
    var endMs: Double
    /// [wordIdx, startMs, endMs] absolute chapter-audio time. May carry extra trailing ints.
    var segments: [[Int]]
    var words: [Word]
}

struct SurahData {
    let surah: Int
    let audioUrl: String
    let surahName: String
    let verses: [Verse]
}

/// What the playing view renders — mirrors the PWA `currentAyah` shape.
struct CurrentAyah: Equatable {
    let key: String
    let text: String
    let translation: String
    let surahName: String
    let segments: [[Int]]
    let words: [Word]
}

// MARK: - Persisted value types (Codable, JSON in UserDefaults)

struct Streak: Codable, Equatable {
    var count: Int
    var lastDate: String?      // "YYYY-MM-DD"
}

struct ListenedEntry: Codable, Equatable {
    var count: Int
    var lastPlayed: Double     // ms epoch
}

struct SavedVerse: Codable, Equatable, Identifiable {
    let surah: Int
    let surahName: String
    let verseKey: String
    let text: String
    let translation: String
    let savedAt: Double        // ms epoch
    var id: String { verseKey + ":" + String(savedAt) }
}

struct LastSession: Codable, Equatable {
    let surah: Int
    let surahName: String
    let verseKey: String
    let mode: String
    let savedAt: Double        // ms epoch
}

// MARK: - View enum

enum AppView { case setup, playing, finished }
