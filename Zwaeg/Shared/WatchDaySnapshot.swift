import Foundation

/// Compact day summary sent to the watch; ActivityKit-free so it also
/// compiles in the watchOS target.
struct WatchDaySnapshot: Codable {
    var consumed: Int
    var target: Int
    var burned: Int
    var glasses: Int
    var waterGoal: Int
    var remainingLabel: String
    var fastingEnd: Date?

    var remaining: Int { max(0, target - consumed) }

    var progress: Double {
        min(1, Double(consumed) / Double(max(1, target)))
    }
}

/// Identifiers derived from ZWAEG_BUNDLE_ID_PREFIX at build time: project.yml
/// writes them into every target's Info.plist and this reads them back, so no
/// identifier lives hardcoded in code and a fork re-brands by changing one
/// xcconfig value. This file is compiled into all four targets.
enum AppIdentifiers {
    /// group.<prefix>.zwaeg, shared by the app, widgets and watch targets.
    static let appGroup = infoString("ZwaegAppGroup")

    static func infoString(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else {
            fatalError("\(key) missing from Info.plist; run `xcodegen generate` (see project.yml)")
        }
        return value
    }
}

/// App-group store on the watch so the complications can read the snapshot
/// written by the watch app.
enum WatchSnapshotStore {
    static let suiteName = AppIdentifiers.appGroup
    private static let key = "watchDaySnapshot"

    static func save(_ snapshot: WatchDaySnapshot) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> WatchDaySnapshot? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WatchDaySnapshot.self, from: data)
    }
}
