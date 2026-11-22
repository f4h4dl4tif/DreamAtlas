import AppKit
import SwiftUI
import UserNotifications

/// Gentle morning nudge to write down a dream. Scheduled as individual notifications for the next two weeks
/// (rather than one repeating one) so mornings you've already recorded a dream are skipped.
@MainActor
final class Reminders: NSObject, ObservableObject {
    static let shared = Reminders()

    @AppStorage("reminderEnabled") var enabled = false { didSet { objectWillChange.send() } }
    /// Minutes after midnight.
    @AppStorage("reminderMinutes") var minutes = 7 * 60 + 30 { didSet { objectWillChange.send(); reschedule() } }
    @Published var denied = false

    private let center = UNUserNotificationCenter.current()
    private static let ids = (0..<14).map { "morning-\($0)" }
    static let category = "MORNING"
    static let recordAction = "RECORD"

    var time: Date {
        get { Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date() }
        set { let c = Calendar.current.dateComponents([.hour, .minute], from: newValue); minutes = (c.hour ?? 7) * 60 + (c.minute ?? 30) }
    }

    func start() {
        center.delegate = self
        let record = UNNotificationAction(identifier: Self.recordAction, title: "Record a Dream", options: [.foreground])
        center.setNotificationCategories([UNNotificationCategory(identifier: Self.category, actions: [record], intentIdentifiers: [])])
        refreshDenied()
        reschedule()
    }

    func setEnabled(_ on: Bool) {
        guard on else { enabled = false; reschedule(); return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.denied = !granted
                    self.enabled = granted
                    self.reschedule()
                }
            }
        }
    }

    func refreshDenied() {
        center.getNotificationSettings { s in
            let d = s.authorizationStatus == .denied
            DispatchQueue.main.async { MainActor.assumeIsolated { self.denied = d } }
        }
    }

    func reschedule() {
        center.removePendingNotificationRequests(withIdentifiers: Self.ids)
        guard enabled else { return }
        let cal = Calendar.current
        let now = Date()
        let recordedDays = Set(JournalStore.shared.data.dreams.map(\.date.day))
        for offset in 0..<14 {
            guard let day = cal.date(byAdding: .day, value: offset, to: now.day),
                  let fire = cal.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day),
                  fire > now, !recordedDays.contains(day) else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Good morning"
            content.body = Self.messages[offset % Self.messages.count]
            content.categoryIdentifier = Self.category
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let req = UNNotificationRequest(identifier: Self.ids[offset], content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
            center.add(req)
        }
    }

    static let messages = [
        "Remember anything from last night? Jot it down before it fades.",
        "Any dream fragments this morning? Even one image is worth keeping.",
        "Take a moment before the day starts — what did you dream?",
    ]
}

extension Reminders: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { QuickCapture.show() }
            completionHandler()
        }
    }
}
