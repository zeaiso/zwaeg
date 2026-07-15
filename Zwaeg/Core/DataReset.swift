import SwiftData
import SwiftUI
import UserNotifications
import WidgetKit

/// Wipes every piece of local data: the SwiftData store, preferences
/// (including the watch snapshot suite), cached buddy renders and photos,
/// pending reminders and the alternate app icon. The profile query turning
/// empty drops the user straight back into onboarding.
enum DataReset {
    @MainActor
    static func wipeAll(context: ModelContext) {
        try? context.delete(model: FoodEntry.self)
        try? context.delete(model: WeightEntry.self)
        try? context.delete(model: WaterDay.self)
        try? context.delete(model: DayNote.self)
        try? context.delete(model: FastingSession.self)
        try? context.delete(model: CustomFood.self)
        try? context.delete(model: CachedProduct.self)
        #if ZWAEG_BATTLES
        try? context.delete(model: Challenge.self)
        #endif
        try? context.delete(model: UserProfile.self)
        try? context.save()

        // Reset the live singletons first so open screens update, then
        // drop the stored domains entirely (removes whatever else is left:
        // closet, reminders, favorites, shopping list, player id).
        Lingo.shared.language = .german
        Themer.shared.look = .munch
        Themer.shared.accent = nil
        HealthKitService.shared.disconnect()
        // Key-by-key through the live instances: removePersistentDomain
        // leaves values cached in-process, which resurface on the next write.
        wipe(UserDefaults.standard)
        if let shared = UserDefaults(suiteName: WatchSnapshotStore.suiteName) {
            wipe(shared)
        }

        let manager = FileManager.default
        if let documents = manager.urls(for: .documentDirectory, in: .userDomainMask).first,
           let files = try? manager.contentsOfDirectory(at: documents,
                                                        includingPropertiesForKeys: nil) {
            for file in files {
                try? manager.removeItem(at: file)
            }
        }

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        if UIApplication.shared.alternateIconName != nil {
            UIApplication.shared.setAlternateIconName(nil)
        }
        // Widgets would otherwise keep showing the last day snapshot.
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func wipe(_ defaults: UserDefaults) {
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
    }
}
