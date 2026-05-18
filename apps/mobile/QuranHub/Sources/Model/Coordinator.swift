import Foundation

/// Owns the single AppModel + AudioEngine + RemindersManager for the app's
/// lifetime so the AVPlayer observer is created exactly once.
@MainActor
final class Coordinator {
    let model: AppModel
    let engine: AudioEngine
    let reminders: RemindersManager

    init() {
        let m = AppModel()
        model = m
        engine = AudioEngine(model: m)
        reminders = RemindersManager(model: m)
    }
}
