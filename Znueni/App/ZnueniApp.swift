import SwiftUI
import SwiftData

@main
struct ZnueniApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
                .environment(\.font, .fredoka(16))
        }
        .modelContainer(for: [UserProfile.self, FoodEntry.self, WeightEntry.self, Challenge.self, WaterDay.self])
    }
}
