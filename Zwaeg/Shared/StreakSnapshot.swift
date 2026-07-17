import Foundation

/// App-group snapshot of the day streak for the home screen widget; the app
/// writes it whenever the diary changes, the extension only reads.
enum StreakSnapshotStore {
    private static let key = "streakSnapshot"

    struct State: Codable {
        var days: Int
        var freezes: Int
        /// Today already has a logged food; the widget dims the flame until then.
        var loggedToday: Bool
        /// Pre-localized caption; the extension has no Lingo tables.
        var label: String
        var midnight: Bool
    }

    static func save(_ state: State) {
        guard let defaults = UserDefaults(suiteName: AppIdentifiers.appGroup),
              let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> State? {
        guard let defaults = UserDefaults(suiteName: AppIdentifiers.appGroup),
              let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(State.self, from: data)
    }
}
