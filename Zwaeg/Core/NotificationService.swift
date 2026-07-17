import Foundation
import UserNotifications

/// User-configurable reminder times, stored as minutes since midnight.
struct ReminderTimes: Codable, Equatable {
    var water: [Int] = [10 * 60, 13 * 60, 16 * 60, 19 * 60]
    var breakfast: Int = 8 * 60
    var lunch: Int = 12 * 60 + 30
    var dinner: Int = 19 * 60
    /// When the daily fasting window begins (eating ends); 20:00 suits 16:8.
    var fasting: Int = 20 * 60

    init() {}

    /// Times stored by an app version without a field keep their values;
    /// only the missing field falls back to its default.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        water = try container.decodeIfPresent([Int].self, forKey: .water) ?? water
        breakfast = try container.decodeIfPresent(Int.self, forKey: .breakfast) ?? breakfast
        lunch = try container.decodeIfPresent(Int.self, forKey: .lunch) ?? lunch
        dinner = try container.decodeIfPresent(Int.self, forKey: .dinner) ?? dinner
        fasting = try container.decodeIfPresent(Int.self, forKey: .fasting) ?? fasting
    }
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
    static func reschedule(waterOn: Bool, mealsOn: Bool, fastingOn: Bool,
                           times: ReminderTimes) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter {
            $0.hasPrefix("water-") || $0.hasPrefix("meal-") || $0 == "fasting-start"
        }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        if waterOn {
            for (index, minutes) in times.water.sorted().enumerated() {
                schedule(id: "water-\(index)",
                         title: "Wasser trinken".loc,
                         body: "Zeit für ein Glas! Dein Ziel: 2 Liter am Tag.".loc,
                         minutes: minutes)
            }
        }
        if mealsOn {
            let meals = MealPlan.enabled(
                from: UserDefaults.standard.string(forKey: MealPlan.storageKey) ?? "")
            if meals.contains(.breakfast) {
                schedule(id: "meal-breakfast", title: "Frühstück loggen".loc,
                         body: "Kurz eintragen, was du gegessen hast.".loc, minutes: times.breakfast)
            }
            if meals.contains(.lunch) {
                schedule(id: "meal-lunch", title: "Mittagessen loggen".loc,
                         body: "Kurz eintragen, was du gegessen hast.".loc, minutes: times.lunch)
            }
            if meals.contains(.dinner) {
                schedule(id: "meal-dinner", title: "Abendessen loggen".loc,
                         body: "Kurz eintragen, was du gegessen hast.".loc, minutes: times.dinner)
            }
        }
        if fastingOn {
            schedule(id: "fasting-start", title: "Fastenfenster startet".loc,
                     body: "Zeit, dein Fasten zu starten. Du schaffst das!".loc,
                     minutes: times.fasting)
        }
    }

    /// One-shot notification when the fasting window completes.
    /// The id is outside the water-/meal- prefixes, so reschedule() leaves it alone.
    static func scheduleFastingEnd(at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Fasten geschafft!".loc
        content.body = "Dein Essensfenster ist offen. Guten Appetit!".loc
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "fasting-end", content: content, trigger: trigger))
    }

    static func cancelFastingEnd() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["fasting-end"])
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
