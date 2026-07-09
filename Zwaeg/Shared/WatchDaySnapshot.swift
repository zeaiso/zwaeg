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

/// App-group store on the watch so the complications can read the snapshot
/// written by the watch app.
enum WatchSnapshotStore {
    static let suiteName = "group.ch.emanuell.zwaeg"
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
