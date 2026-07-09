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
