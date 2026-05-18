import Foundation

enum QuranAPIError: LocalizedError {
    case audio(Int)
    case message(String)
    var errorDescription: String? {
        switch self {
        case .audio(let s): return "Audio API error: \(s)"
        case .message(let m): return m
        }
    }
}

/// Mirrors the PWA `fetchSurahData`: bundled text + translation, plus live
/// audio URL / per-verse timestamps / per-word segments & glossary.
enum QuranAPI {

    // chapter_recitations/{reciter}/{surah}?segments=true
    private struct RecitationResponse: Decodable {
        struct AudioFile: Decodable {
            let audio_url: String
            let timestamps: [Timestamp]?
        }
        struct Timestamp: Decodable {
            let verse_key: String
            let timestamp_from: Double?
            let timestamp_to: Double?
            let segments: [[Int]]?
        }
        let audio_file: AudioFile?
    }

    // verses/by_chapter/{surah}?words=true
    private struct VersesResponse: Decodable {
        struct V: Decodable {
            let verse_key: String
            let words: [W]?
        }
        struct W: Decodable {
            let position: Int?
            let char_type_name: String?
            let text_uthmani: String?
            let text: String?
            let translation: Tx?
            let transliteration: Tx?
        }
        struct Tx: Decodable { let text: String? }
        let verses: [V]
    }

    static func fetchSurahData(surahId: Int, reciterId: Int) async throws -> SurahData {
        let recURL = URL(string: "https://api.quran.com/api/v4/chapter_recitations/\(reciterId)/\(surahId)?segments=true")!
        let versesURL = URL(string: "https://api.quran.com/api/v4/verses/by_chapter/\(surahId)?fields=text_uthmani&words=true&word_fields=text_uthmani&per_page=300")!

        // Audio + timestamps (required). Words (optional — tooltips/glossary).
        async let recPair = URLSession.shared.data(from: recURL)
        async let versesPairTry = try? URLSession.shared.data(from: versesURL)

        let (recData, recResp) = try await recPair
        guard let http = recResp as? HTTPURLResponse, http.statusCode == 200 else {
            throw QuranAPIError.audio((recResp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let rec = try JSONDecoder().decode(RecitationResponse.self, from: recData)
        guard let audio = rec.audio_file else { throw QuranAPIError.message("Chapter audio not found") }

        var tsByKey: [String: RecitationResponse.Timestamp] = [:]
        for t in audio.timestamps ?? [] { tsByKey[t.verse_key] = t }

        var wordsByKey: [String: [Word]] = [:]
        if let versesPair = await versesPairTry,
           let parsed = try? JSONDecoder().decode(VersesResponse.self, from: versesPair.0) {
            for v in parsed.verses {
                let ws = (v.words ?? [])
                    .filter { $0.char_type_name == "word" }
                    .map { w in
                        Word(position: w.position ?? 0,
                             text: w.text_uthmani ?? w.text ?? "",
                             translation: w.translation?.text ?? "",
                             transliteration: w.transliteration?.text ?? "")
                    }
                wordsByKey[v.verse_key] = ws
            }
        }

        let bundled = QuranText.verses(surahId)
        let name = chapter(surahId)?.nameSimple ?? "Surah \(surahId)"

        var verses: [Verse] = bundled.map { bv in
            let key = "\(surahId):\(bv.n)"
            let ts = tsByKey[key]
            return Verse(
                num: bv.n,
                key: key,
                text: bv.ar,
                translation: bv.en.isEmpty ? "Translation not available" : bv.en,
                startMs: ts?.timestamp_from ?? 0,
                endMs: ts?.timestamp_to ?? 0,
                segments: ts?.segments ?? [],
                words: wordsByKey[key] ?? []
            )
        }

        // Fix degenerate timestamps (endMs <= startMs) — some reciters return
        // zero-duration verses that can never be "active" in the time-range check.
        for i in verses.indices {
            if verses[i].endMs <= verses[i].startMs {
                verses[i].endMs = (i + 1 < verses.count ? verses[i + 1].startMs : verses[i].startMs + 5000)
            }
        }

        return SurahData(surah: surahId, audioUrl: audio.audio_url, surahName: name, verses: verses)
    }
}
