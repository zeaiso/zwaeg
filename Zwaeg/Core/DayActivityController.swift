import ActivityKit
import Foundation
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
}
