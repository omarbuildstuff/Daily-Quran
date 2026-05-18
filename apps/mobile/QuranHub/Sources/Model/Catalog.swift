import Foundation

// Ported verbatim from apps/web/src/app/page.jsx

let RECITERS: [Reciter] = [
    Reciter(id: 7,   name: "Mishari Rashid al-Afasy (Studio)"),
    Reciter(id: 173, name: "Mishari Rashid al-Afasy (Live)"),
    Reciter(id: 3,   name: "Abdur-Rahman as-Sudais"),
    Reciter(id: 12,  name: "Mahmoud Khalil Al-Husary"),
    Reciter(id: 2,   name: "AbdulBaset AbdulSamad"),
    Reciter(id: 10,  name: "Sa'ud ash-Shuraym"),
    Reciter(id: 5,   name: "Hani ar-Rifai"),
    Reciter(id: 4,   name: "Abu Bakr Ash-Shatri"),
    Reciter(id: 13,  name: "Saad Al-Ghamdi"),
    Reciter(id: 161, name: "Khalifah Al-Tunaiji"),
]

let DURATIONS: [DurationOption] = [
    DurationOption(label: "5 min",  value: 5 * 60),
    DurationOption(label: "10 min", value: 10 * 60),
    DurationOption(label: "15 min", value: 15 * 60),
]

let MOODS: [Mood] = [
    Mood(id: "fear",       label: "Fear of Allah",      emoji: "🕊️", surahs: [59, 101, 81, 82, 99]),
    Mood(id: "patience",   label: "Patience",           emoji: "⌛", surahs: [12, 103, 94, 2]),
    Mood(id: "gratitude",  label: "Gratitude",          emoji: "🌿", surahs: [55, 14, 93, 108]),
    Mood(id: "afterlife",  label: "Afterlife",          emoji: "🌅", surahs: [75, 56, 69, 77, 101]),
    Mood(id: "repentance", label: "Repentance",         emoji: "💧", surahs: [66, 25, 110, 71]),
    Mood(id: "hope",       label: "Hope",               emoji: "✨", surahs: [39, 36, 93, 94]),
    Mood(id: "tawakkul",   label: "Tawakkul",           emoji: "🤲", surahs: [65, 8, 67, 1]),
    Mood(id: "dunya",      label: "Loving this Dunya",  emoji: "🌍", surahs: [57, 102, 104, 75]),
]

func getGreeting(_ date: Date = Date()) -> (line1: String, line2: String) {
    let hour = Calendar.current.component(.hour, from: date)
    if hour < 5  { return ("Late night?",   "Let the Quran accompany you.") }
    if hour < 12 { return ("Good morning.", "Time to listen.") }
    if hour < 17 { return ("Bismillah.",    "Let's begin.") }
    if hour < 21 { return ("Good evening.", "Unwind with Quran.") }
    return ("Wind down.", "Listen before you sleep.")
}

func formatTime(_ seconds: Int) -> String {
    let mins = seconds / 60
    let secs = seconds % 60
    return "\(mins):" + String(format: "%02d", secs)
}
