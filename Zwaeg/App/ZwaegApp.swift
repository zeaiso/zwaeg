import SwiftUI
import SwiftData

@main
struct ZwaegApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        PhoneWatchLink.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.font, .fredoka(16))
        }
        .modelContainer(AppModel.container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Self.mergePendingWater()
            }
        }
    }

    /// Glasses tapped on the water widget while the app was closed sit in the
    /// app group; fold them into the store before the diary renders.
    @MainActor
    private static func mergePendingWater() {
        let pending = WaterPendingStore.drain()
        guard !pending.isEmpty else { return }
        let context = AppModel.container.mainContext
        let days = (try? context.fetch(FetchDescriptor<WaterDay>())) ?? []
        for (day, glasses) in pending {
            if let entry = days.first(where: { $0.day == day }) {
                entry.glasses += glasses
            } else {
                context.insert(WaterDay(day: day, glasses: glasses))
            }
        }
        try? context.save()
        DayActivityController.syncFromStore()
    }
}
