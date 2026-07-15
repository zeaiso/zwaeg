import SwiftData

/// One ModelContainer shared by the app UI, the App Intents and the watch link.
enum AppModel {
    static let container: ModelContainer = {
        // Zwäg is local first: personal data stays on the device. Battles are the
        // one exception and they talk to the CloudKit *public* database by hand
        // (see ChallengeSyncService), never through SwiftData.
        //
        // This must stay `.none`. SwiftData defaults to `.automatic`, which turns
        // on private-database mirroring as soon as the app carries an iCloud
        // entitlement: that would upload every meal, weight and note, and it
        // refuses to load the store at all because the models have non-optional
        // attributes without defaults. `groupContainer` stays automatic so the
        // store keeps living in the shared app group the widget reads from.
        //
        // Challenge is registered in every build configuration, battles flag or
        // not: dropping an entity from the schema migrates its table away, so a
        // battles-off build would destroy battle data recorded by a battles-on
        // build sharing the same store.
        let configuration = ModelConfiguration(cloudKitDatabase: .none)
        // swiftlint:disable:next force_try
        return try! ModelContainer(for: UserProfile.self, FoodEntry.self, WeightEntry.self,
                                   Challenge.self, WaterDay.self, DayNote.self, FastingSession.self,
                                   CustomFood.self, CachedProduct.self,
                                   configurations: configuration)
    }()
}
