import Foundation

/// Bundled offline corpus — all 114 surahs, Arabic (Uthmani) + Khattab English.
/// Same two sources the PWA fetched at runtime, frozen at build time.
enum QuranText {
    struct BundledVerse: Decodable { let n: Int; let ar: String; let en: String }
    private struct Surah: Decodable { let verses: [BundledVerse] }

    private static let data: [String: Surah] = {
        guard let url = Bundle.main.url(forResource: "quran-text", withExtension: "json"),
              let raw = try? Data(contentsOf: url),
              let map = try? JSONDecoder().decode([String: Surah].self, from: raw)
        else { return [:] }
        return map
    }()

    static func verses(_ surahId: Int) -> [BundledVerse] {
        data[String(surahId)]?.verses ?? []
    }
}
