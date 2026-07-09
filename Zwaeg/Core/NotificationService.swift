import UserNotifications

/// Local notification scheduling for water and meal reminders.
/// Local notifications need no Apple Developer membership or server.
enum NotificationService {
    private static let waterIDs = ["water-10", "water-13", "water-16", "water-19"]
    private static let mealIDs = ["meal-breakfast", "meal-lunch", "meal-dinner"]

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized {
            return true
        }
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func updateWaterReminders(enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: waterIDs)
        guard enabled else { return }
        for (index, hour) in [10, 13, 16, 19].enumerated() {
            var components = DateComponents()
            components.hour = hour
            components.minute = 0
            let content = UNMutableNotificationContent()
            content.title = "Wasser trinken"
            content.body = "Zeit für ein Glas! Dein Ziel: 2 Liter am Tag."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            center.add(UNNotificationRequest(identifier: waterIDs[index], content: content, trigger: trigger))
        }
    }

    static func updateMealReminders(enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: mealIDs)
        guard enabled else { return }
        let meals: [(String, String, Int, Int)] = [
            ("meal-breakfast", "Frühstück loggen", 8, 0),
            ("meal-lunch", "Mittagessen loggen", 12, 30),
            ("meal-dinner", "Abendessen loggen", 19, 0),
        ]
        for (id, title, hour, minute) in meals {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = "Kurz eintragen, was du gegessen hast. Dein Buddy zählt auf dich!"
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }
}
