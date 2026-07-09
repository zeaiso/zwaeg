import ActivityKit
import Foundation

/// Shared between the app and the widget extension: the state of today's
/// diary shown on the lock screen and in the Dynamic Island.
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
