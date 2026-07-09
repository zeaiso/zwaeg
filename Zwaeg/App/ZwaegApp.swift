import SwiftUI
import SwiftData

@main
struct ZwaegApp: App {
    init() {
        PhoneWatchLink.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.font, .fredoka(16))
        }
        .modelContainer(AppModel.container)
    }
}
