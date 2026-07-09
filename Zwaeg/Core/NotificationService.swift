import Foundation
import UserNotifications

/// User-configurable reminder times, stored as minutes since midnight.
struct ReminderTimes: Codable, Equatable {
    var water: [Int] = [10 * 60, 13 * 60, 16 * 60, 19 * 60]
    var breakfast: Int = 8 * 60
    var lunch: Int = 12 * 60 + 30
    var dinner: Int = 19 * 60
}

enum ReminderStore {
    private static let key = "reminderTimes"

    static func load() -> ReminderTimes {
        guard let data = UserDefaults.standard.data(forKey: key),
              let times = try? JSONDecoder().decode(ReminderTimes.self, from: data) else {
            return ReminderTimes()
        }
        return times
    }

    static func save(_ times: ReminderTimes) {
        guard let data = try? JSONEncoder().encode(times) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

/// Local notification scheduling for water and meal reminders.
/// Local notifications need no Apple Developer membership or server.
enum NotificationService {
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized {
            return true
        }
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Replaces all scheduled reminders with the given configuration.
    static func reschedule(waterOn: Bool, mealsOn: Bool, times: ReminderTimes) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix("water-") || $0.hasPrefix("meal-") }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        if waterOn {
            for (index, minutes) in times.water.sorted().enumerated() {
                schedule(id: "water-\(index)",
                         title: "Wasser trinken",
                         body: "Zeit für ein Glas! Dein Ziel: 2 Liter am Tag.",
                         minutes: minutes)
            }
        }
        if mealsOn {
            schedule(id: "meal-breakfast", title: "Frühstück loggen",
                     body: "Kurz eintragen, was du gegessen hast.", minutes: times.breakfast)
            schedule(id: "meal-lunch", title: "Mittagessen loggen",
                     body: "Kurz eintragen, was du gegessen hast.", minutes: times.lunch)
            schedule(id: "meal-dinner", title: "Abendessen loggen",
                     body: "Kurz eintragen, was du gegessen hast.", minutes: times.dinner)
        }
    }

    private static func schedule(id: String, title: String, body: String, minutes: Int) {
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
