import ActivityKit
import Foundation

/// Shared between the app and the widget extension: the state of today's
/// diary shown on the lock screen and in the Dynamic Island.
/// App-group store so the home screen widget can read today's numbers.
enum DaySnapshotStore {
    static let suiteName = "group.ch.emanuell.zwaeg"
    private static let key = "daySnapshot"

    static func save(_ state: DayActivityAttributes.ContentState) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> DayActivityAttributes.ContentState? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(DayActivityAttributes.ContentState.self, from: data)
    }
}

struct DayActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var consumed: Int
        var target: Int
        var burned: Int
        var glasses: Int
        var waterGoal: Int
        /// Goal end of a running fast; nil when not fasting.
        var fastingEnd: Date?
        /// Pre-localized labels; the extension has no Lingo tables.
        var remainingLabel: String
        var fastingLabel: String
        /// Matches the app's Midnight look on the lock screen banner.
        var midnight: Bool

        var remaining: Int { max(0, target - consumed) }

        var progress: Double {
            min(1, Double(consumed) / Double(max(1, target)))
        }
    }
}
