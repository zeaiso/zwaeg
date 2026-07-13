import Foundation
import SwiftData
import WatchConnectivity

/// iPhone side of the watch connection: pushes the day snapshot over as
/// application context and applies water logged on the wrist.
final class PhoneWatchLink: NSObject, WCSessionDelegate {
    static let shared = PhoneWatchLink()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func push(_ snapshot: WatchDaySnapshot) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              let data = try? JSONEncoder().encode(snapshot) else { return }
        try? WCSession.default.updateApplicationContext(["snapshot": data])
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        applyWater(message)
    }

    /// Queued wrist taps sent while the phone app wasn't reachable.
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        applyWater(userInfo)
    }

    private func applyWater(_ message: [String: Any]) {
        // Clamped so a misbehaving counterpart cannot inject absurd values.
        guard let add = message["addWater"] as? Int, (-5...5).contains(add) else { return }
        Task { @MainActor in
            let context = AppModel.container.mainContext
            let today = Calendar.current.startOfDay(for: .now)
            let days = (try? context.fetch(FetchDescriptor<WaterDay>())) ?? []
            if let entry = days.first(where: { $0.day == today }) {
                entry.glasses = min(99, max(0, entry.glasses + add))
            } else if add > 0 {
                context.insert(WaterDay(day: today, glasses: add))
            }
            try? context.save()
            DayActivityController.syncFromStore()
        }
    }
}
