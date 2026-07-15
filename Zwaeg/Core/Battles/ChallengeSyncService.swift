// Battles are opt-in at build time: they need CloudKit and therefore a paid
// Apple Developer account. See Config/Battles.yml and docs/DEVELOPMENT.md.
#if ZWAEG_BATTLES

import Foundation
import CloudKit

enum BattleSyncError: LocalizedError, Equatable {
    case noAccount
    case restricted
    case network
    case challengeNotFound(String)
    case failed

    /// CloudKit reports the same conditions through a dozen different codes;
    /// collapse them into the four the UI can actually act on.
    init(_ error: Error) {
        guard let ckError = error as? CKError else {
            self = .failed
            return
        }
        switch ckError.code {
        case .notAuthenticated:
            self = .noAccount
        case .managedAccountRestricted, .permissionFailure:
            self = .restricted
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited:
            self = .network
        default:
            self = .failed
        }
    }

    var errorDescription: String? {
        switch self {
        case .noAccount:
            return "Melde dich in den iPhone-Einstellungen bei iCloud an, um gegen Freunde anzutreten.".loc
        case .restricted:
            return "iCloud ist auf diesem Gerät eingeschränkt.".loc
        case .network:
            return "Keine Verbindung zu iCloud. Prüf dein Internet und versuch es nochmal.".loc
        case .challengeNotFound(let code):
            return "Challenge %@ nicht gefunden.".loc(code)
        case .failed:
            return "Das hat nicht geklappt. Versuch es später nochmal.".loc
        }
    }
}

/// Pushes my scores and pulls the other participants' scores for a challenge.
///
/// Everything lives in the public database and participants find each other
/// purely through the 6-character join code: no iCloud identity is read, and
/// nothing ties a score record to an Apple Account. The only personal field is
/// the display name people type into their profile.
///
/// Record types (see docs/DEVELOPMENT.md for the dashboard setup):
/// - "Challenge": code, name, metric, startDay, endDay
/// - "Score": challengeCode, participantID, participantName, dayKey, value
/// `Score.challengeCode` must be marked Queryable in the CloudKit Dashboard,
/// otherwise `pullAllScores` fails with an invalid-arguments error.
struct ChallengeSyncService {
    static let shared = ChallengeSyncService()

    static let containerID = "iCloud.ch.emanuell.zwaeg"

    private var container: CKContainer {
        CKContainer(identifier: Self.containerID)
    }

    private var database: CKDatabase {
        container.publicCloudDatabase
    }

    /// iCloud is optional: the rest of the app works fine without it, so callers
    /// use this to explain why battles are unavailable instead of failing blind.
    func isAvailable() async -> Bool {
        let status = try? await container.accountStatus()
        return status == .available
    }

    func refresh(_ challenge: Challenge) async throws {
        try await pushMyScores(challenge)
        try await pullAllScores(challenge)
    }

    /// Claims a fresh join code and publishes the challenge under it, returning
    /// the code that won. Codes are generated client-side, so on the (roughly
    /// 1-in-a-billion) chance of a collision the save is rejected and we simply
    /// draw another one rather than silently joining two groups together.
    func publishNewChallenge(name: String, metric: BattleMetric,
                             start: Date, end: Date) async throws -> String {
        for _ in 0..<3 {
            let code = BattleScoreEngine.makeCode()
            let record = CKRecord(recordType: "Challenge",
                                  recordID: CKRecord.ID(recordName: "challenge-\(code)"))
            record["code"] = code
            record["name"] = name
            record["metric"] = metric.rawValue
            record["startDay"] = start
            record["endDay"] = end
            do {
                try await database.save(record)
                return code
            } catch let error as CKError where error.code == .serverRecordChanged {
                continue
            } catch {
                throw BattleSyncError(error)
            }
        }
        throw BattleSyncError.failed
    }

    func fetchChallenge(code: String) async throws -> (name: String, metric: BattleMetric, start: Date, end: Date) {
        let recordID = CKRecord.ID(recordName: "challenge-\(code)")
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            throw BattleSyncError.challengeNotFound(code)
        } catch {
            throw BattleSyncError(error)
        }
        guard let name = record["name"] as? String,
              let metricRaw = record["metric"] as? String,
              let metric = BattleMetric(rawValue: metricRaw),
              let start = record["startDay"] as? Date,
              let end = record["endDay"] as? Date else {
            throw BattleSyncError.challengeNotFound(code)
        }
        return (String(name.prefix(40)), metric, start, end)
    }

    // MARK: - Sync

    /// Score records are keyed by challenge + participant + day, so my own rows
    /// are mine alone to overwrite. `.allKeys` skips the change-tag check, which
    /// saves a fetch round trip per day; the public database has no atomic
    /// commits, hence `atomically: false`.
    @MainActor
    private func pushMyScores(_ challenge: Challenge) async throws {
        guard let me = challenge.participants.first(where: \.isMe), !me.scores.isEmpty else { return }
        let records = me.scores.map { dayKey, value -> CKRecord in
            let recordID = CKRecord.ID(recordName: "score-\(challenge.code)-\(me.id)-\(dayKey)")
            let record = CKRecord(recordType: "Score", recordID: recordID)
            record["challengeCode"] = challenge.code
            record["participantID"] = me.id
            record["participantName"] = me.name
            record["dayKey"] = dayKey
            record["value"] = value
            return record
        }
        do {
            _ = try await database.modifyRecords(saving: records, deleting: [],
                                                 savePolicy: .allKeys, atomically: false)
        } catch {
            throw BattleSyncError(error)
        }
    }

    @MainActor
    private func pullAllScores(_ challenge: Challenge) async throws {
        let query = CKQuery(recordType: "Score",
                            predicate: NSPredicate(format: "challengeCode == %@", challenge.code))
        var participants = challenge.participants
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let page: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
            do {
                if let cursor {
                    page = try await database.records(continuingMatchFrom: cursor)
                } else {
                    page = try await database.records(matching: query, resultsLimit: 200)
                }
            } catch {
                throw BattleSyncError(error)
            }

            for (_, result) in page.matchResults {
                guard let record = try? result.get(),
                      let entry = SanitizedScore(record) else { continue }

                if let index = participants.firstIndex(where: { $0.id == entry.participantID }) {
                    // My own rows are authoritative locally; never let the
                    // public database overwrite them.
                    if !participants[index].isMe {
                        participants[index].scores[entry.dayKey] = entry.value
                        participants[index].name = entry.name
                    }
                } else {
                    participants.append(ParticipantScore(
                        id: entry.participantID, name: entry.name, isMe: false,
                        scores: [entry.dayKey: entry.value]))
                }
            }
            cursor = page.queryCursor
        } while cursor != nil

        challenge.participants = participants
    }
}

/// The public database is writable by anyone with the join code, so every field
/// is treated as untrusted input: names are stripped of control characters and
/// capped, ids and day keys are length-checked, scores clamped to a plausible range.
private struct SanitizedScore {
    let participantID: String
    let name: String
    let dayKey: String
    let value: Double

    init?(_ record: CKRecord) {
        guard let participantID = record["participantID"] as? String,
              let rawName = record["participantName"] as? String,
              let dayKey = record["dayKey"] as? String,
              let rawValue = record["value"] as? Double else { return nil }

        let name = String(rawName.unicodeScalars
            .filter { !CharacterSet.controlCharacters.contains($0) }
            .prefix(40))

        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              !participantID.isEmpty, participantID.count <= 64,
              BattleDay.date(for: dayKey) != nil,
              rawValue.isFinite else { return nil }

        self.participantID = participantID
        self.name = String(name)
        self.dayKey = dayKey
        self.value = min(500_000, max(-500_000, rawValue))
    }
}

#endif
