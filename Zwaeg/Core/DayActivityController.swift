import ActivityKit
import Foundation
import SwiftData
import WidgetKit

/// Starts and updates the Live Activity that mirrors today's diary on the
/// lock screen and in the Dynamic Island. Local updates only, no push needed.
enum DayActivityController {
    static func sync(consumed: Int, target: Int, burned: Int,
                     glasses: Int, waterGoal: Int, fastingEnd: Date?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let activeFastEnd = fastingEnd.flatMap { $0 > .now ? $0 : nil }
        let state = DayActivityAttributes.ContentState(
            consumed: consumed,
            target: target,
            burned: burned,
            glasses: glasses,
            waterGoal: waterGoal,
            fastingEnd: activeFastEnd,
            remainingLabel: "kcal übrig".loc,
            fastingLabel: "Fasten".loc,
            midnight: Themer.shared.look == .midnight)
        DaySnapshotStore.save(state)
        WidgetCenter.shared.reloadAllTimelines()
        PhoneWatchLink.shared.push(WatchDaySnapshot(
            consumed: consumed, target: target, burned: burned,
            glasses: glasses, waterGoal: waterGoal,
            remainingLabel: state.remainingLabel, fastingEnd: activeFastEnd))
        let midnightTonight = Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400)
        let content = ActivityContent(state: state, staleDate: midnightTonight)
        Task {
            if let existing = Activity<DayActivityAttributes>.activities.first {
                await existing.update(content)
            } else if consumed > 0 || activeFastEnd != nil {
                _ = try? Activity<DayActivityAttributes>.request(
                    attributes: DayActivityAttributes(), content: content)
            }
        }
    }

    /// Recomputes today's numbers straight from the store; used by App Intents
    /// and the watch link, which run without the diary view.
    @MainActor
    static func syncFromStore() {
        let context = AppModel.container.mainContext
        guard let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first else { return }
        let today = Calendar.current.startOfDay(for: .now)
        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let consumed = entries.filter { $0.day == today }.totalCalories
        let glasses = ((try? context.fetch(FetchDescriptor<WaterDay>())) ?? [])
            .first { $0.day == today }?.glasses ?? 0
        let fastingEnd = ((try? context.fetch(FetchDescriptor<FastingSession>())) ?? [])
            .first { $0.isActive }?.goalEnd
        sync(consumed: consumed, target: profile.dailyCalorieTarget, burned: 0,
             glasses: glasses, waterGoal: profile.waterGoalGlasses, fastingEnd: fastingEnd)
    }
}
