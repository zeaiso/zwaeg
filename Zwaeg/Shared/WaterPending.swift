import AppIntents
import Foundation
import WidgetKit

/// Glasses logged from the home screen widget, parked in the app group until
/// the app runs: the widget extension can't open the SwiftData store, so the
/// intent only counts, and the app merges the count into WaterDay when it
/// next becomes active.
enum WaterPendingStore {
    private static let key = "pendingWaterGlasses"

    /// Day-keyed so a glass tapped before midnight lands on the right day
    /// even when the app only merges it the morning after.
    static func add(_ glasses: Int, day: Date = .now) {
        guard let defaults = UserDefaults(suiteName: AppIdentifiers.appGroup) else { return }
        var table = defaults.dictionary(forKey: key) as? [String: Int] ?? [:]
        table[Self.formatter.string(from: day), default: 0] += glasses
        defaults.set(table, forKey: key)
    }

    /// Returns and clears the parked glasses.
    static func drain() -> [(day: Date, glasses: Int)] {
        guard let defaults = UserDefaults(suiteName: AppIdentifiers.appGroup),
              let table = defaults.dictionary(forKey: key) as? [String: Int],
              !table.isEmpty else { return [] }
        defaults.removeObject(forKey: key)
        return table.compactMap { entry in
            formatter.date(from: entry.key).map {
                (Calendar.current.startOfDay(for: $0), entry.value)
            }
        }
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

/// Plus button on the water widget. Compiled into app and extension; when the
/// extension runs it, it can't reach SwiftData, so it parks the glass in the
/// app group and bumps the snapshot the widgets render — the count is right
/// on screen immediately and the app catches up on next activation.
struct AddWaterGlassIntent: AppIntent {
    static let title: LocalizedStringResource = "Glas Wasser loggen"
    /// Siri phrases are LogWaterIntent's job; this one is widget-only.
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        WaterPendingStore.add(1)
        if var state = DaySnapshotStore.load() {
            state.glasses += 1
            DaySnapshotStore.save(state)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
