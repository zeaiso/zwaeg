import SwiftUI
import SwiftData

@main
struct ZwaegApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.font, .fredoka(16))
        }
        .modelContainer(for: [UserProfile.self, FoodEntry.self, WeightEntry.self, Challenge.self,
                              WaterDay.self, DayNote.self, FastingSession.self])
    }
}
