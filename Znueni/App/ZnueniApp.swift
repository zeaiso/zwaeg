import SwiftUI
import SwiftData

@main
struct ZnueniApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [UserProfile.self, FoodEntry.self, WeightEntry.self, Challenge.self])
    }
}
