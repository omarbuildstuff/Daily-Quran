import Foundation
import UserNotifications

/// Native equivalent of the PWA's 60s service-worker reminder.
/// - A one-shot local notification scheduled for the next due time (fires even
///   when the app is closed); rescheduled on launch/active/session-end so it
///   only fires when the user hasn't listened that day.
/// - The in-app banner parity check while the app is open.
@MainActor
final class RemindersManager {
    private let model: AppModel
    private var bannerTimer: Timer?
    private var shownToday: String?

    private let utcDay: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(model: AppModel) { self.model = model }

    static let reminderID = "daily-reminder"

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    /// Cancel + reschedule the next due notification. Call on launch, foreground,
    /// session end, and whenever reminderEnabled / reminderTime change.
    func sync() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderID])
        guard model.reminderEnabled else { return }

        let parts = model.reminderTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        let (h, m) = (parts[0], parts[1])

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let now = Date()
        let todayStr = utcDay.string(from: now)
        let listenedToday = model.streak.lastDate == todayStr

        var fire = cal.date(bySettingHour: h, minute: m, second: 0, of: now) ?? now
        // If today's slot already passed, or already listened today → tomorrow.
        if fire <= now || listenedToday {
            fire = cal.date(byAdding: .day, value: 1, to: fire) ?? fire
        }

        let content = UNMutableNotificationContent()
        content.title = "Time for your daily Quran 🤲"
        content.body = "You haven't listened today yet. Take a few minutes."
        content.sound = .default

        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.reminderID, content: content, trigger: trigger))
    }

    // In-app banner — verbatim port of the PWA 60s check.
    func startBannerCheck() {
        stopBannerCheck()
        check()
        bannerTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
    }

    func stopBannerCheck() { bannerTimer?.invalidate(); bannerTimer = nil }

    private func check() {
        guard model.reminderEnabled, !model.reminderTime.isEmpty else { return }
        let now = Date()
        let todayStr = utcDay.string(from: now)
        if model.streak.lastDate == todayStr { return }   // already listened today
        if shownToday == todayStr { return }               // already notified today

        let parts = model.reminderTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        var cal = Calendar.current
        let target = cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: now) ?? now
        if now < target { return }                          // not yet time

        shownToday = todayStr
        model.showReminderBanner = true
    }
}
