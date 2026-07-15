import Foundation
import Observation
import WatchConnectivity
import WidgetKit

/// Watch side of the connection: receives the day snapshot from the iPhone
/// and sends water logged on the wrist back.
@Observable
final class WatchLink: NSObject, WCSessionDelegate {
    static let shared = WatchLink()

    var snapshot: WatchDaySnapshot?

    override private init() {
        super.init()
        #if DEBUG
        // Simulator screenshots: no paired iPhone ever syncs a snapshot there,
        // so -seed-snapshot fakes a lived-in day. Debug builds only.
        if CommandLine.arguments.contains("-seed-snapshot") {
            snapshot = WatchDaySnapshot(
                consumed: 980, target: 1950, burned: 320, glasses: 4, waterGoal: 8,
                remainingLabel: "kcal übrig", fastingEnd: .now.addingTimeInterval(3 * 3600))
            return
        }
        #endif
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        readContext(WCSession.default.receivedApplicationContext)
    }

    func addWater() {
        snapshot?.glasses += 1
        guard WCSession.default.activationState == .activated else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["addWater": 1], replyHandler: nil)
        } else {
            // Queued delivery, so wrist taps survive the phone app not
            // running; applied via didReceiveUserInfo on the next launch.
            WCSession.default.transferUserInfo(["addWater": 1])
        }
    }

    private func readContext(_ context: [String: Any]) {
        guard let data = context["snapshot"] as? Data,
              let decoded = try? JSONDecoder().decode(WatchDaySnapshot.self, from: data) else { return }
        WatchSnapshotStore.save(decoded)
        WidgetCenter.shared.reloadAllTimelines()
        Task { @MainActor in
            snapshot = decoded
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        readContext(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        readContext(applicationContext)
    }
}
