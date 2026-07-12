import SwiftData

/// One ModelContainer shared by the app UI, the App Intents and the watch link.
enum AppModel {
    static let container: ModelContainer = {
        // swiftlint:disable:next force_try
        try! ModelContainer(for: UserProfile.self, FoodEntry.self, WeightEntry.self,
                            Challenge.self, WaterDay.self, DayNote.self, FastingSession.self,
                            CustomFood.self, CachedProduct.self)
    }()
}
