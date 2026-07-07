import SwiftUI
import SwiftData

@main
struct ZnueniApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [UserProfile.self, FoodEntry.self, WeightEntry.self, Challenge.self, WaterDay.self])
    }
}
