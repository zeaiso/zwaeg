import Foundation
import Observation
import WatchConnectivity

/// Watch side of the connection: receives the day snapshot from the iPhone
/// and sends water logged on the wrist back.
@Observable
final class WatchLink: NSObject, WCSessionDelegate {
    static let shared = WatchLink()

    var snapshot: WatchDaySnapshot?

    override private init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        readContext(WCSession.default.receivedApplicationContext)
    }

    func addWater() {
        snapshot?.glasses += 1
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.sendMessage(["addWater": 1], replyHandler: nil)
    }

    private func readContext(_ context: [String: Any]) {
        guard let data = context["snapshot"] as? Data,
              let decoded = try? JSONDecoder().decode(WatchDaySnapshot.self, from: data) else { return }
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
