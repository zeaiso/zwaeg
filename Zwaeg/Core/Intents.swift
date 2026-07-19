import AppIntents
import SwiftData

/// "Hey Siri, logge Wasser in Zwäg" — adds glasses to today's water.
struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Wasser loggen"
    static let description = IntentDescription("Loggt Gläser Wasser in Zwäg.")

    @Parameter(title: "Gläser", default: 1, inclusiveRange: (1, 8))
    var glasses: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = AppModel.container.mainContext
        let today = Calendar.current.startOfDay(for: .now)
        let days = (try? context.fetch(FetchDescriptor<WaterDay>())) ?? []
        let total: Int
        if let entry = days.first(where: { $0.day == today }) {
            entry.glasses += glasses
            total = entry.glasses
        } else {
            context.insert(WaterDay(day: today, glasses: glasses))
            total = glasses
        }
        try context.save()
        DayActivityController.syncFromStore()
        return .result(dialog: IntentDialog(stringLiteral:
            "Wasser geloggt. Heute insgesamt: %d Gläser.".loc(total)))
    }
}

/// "Hey Siri, wie viele Kalorien habe ich noch in Zwäg" — reads the day budget.
struct RemainingCaloriesIntent: AppIntent {
    static let title: LocalizedStringResource = "Übrige Kalorien"
    static let description = IntentDescription("Sagt dir, wie viele Kalorien heute noch übrig sind.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = AppModel.container.mainContext
        guard let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first else {
            return .result(dialog: IntentDialog(stringLiteral: "Zwäg"))
        }
        let today = Calendar.current.startOfDay(for: .now)
        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let consumed = entries.filter { $0.day == today }.totalCalories
        let remaining = profile.dailyCalorieTarget - consumed
        return .result(dialog: IntentDialog(stringLiteral:
            "Du hast noch %@ kcal übrig.".loc(remaining.formatted())))
    }
}

struct ZwaegShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogWaterIntent(),
                    phrases: [
                        "Logge Wasser in \(.applicationName)",
                        "Log water in \(.applicationName)",
                    ],
                    shortTitle: "Wasser",
                    systemImageName: "drop.fill")
        AppShortcut(intent: RemainingCaloriesIntent(),
                    phrases: [
                        "Wie viele Kalorien habe ich noch in \(.applicationName)",
                        "How many calories are left in \(.applicationName)",
                    ],
                    shortTitle: "Kalorien",
                    systemImageName: "flame.fill")
    }
}
