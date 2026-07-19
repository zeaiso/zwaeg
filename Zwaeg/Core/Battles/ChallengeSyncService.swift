// Battles are opt-in at build time: they need CloudKit and therefore a paid
// Apple Developer account. See Config/Battles.yml and docs/DEVELOPMENT.md.
#if ZWAEG_BATTLES

import Foundation
import CloudKit

enum BattleSyncError: LocalizedError {
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

    /// The user-facing text for any error a battle operation throws; the one
    /// place that decides how a non-BattleSyncError leaking through is worded.
    static func message(for error: Error) -> String {
        ((error as? BattleSyncError) ?? .failed).errorDescription ?? ""
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

    /// iCloud.<prefix>.zwaeg, derived from ZWAEG_BUNDLE_ID_PREFIX at build time.
    static let containerID = AppIdentifiers.infoString("ZwaegCloudKitContainer")

    private var container: CKContainer {
        CKContainer(identifier: Self.containerID)
    }

    private var database: CKDatabase {
        container.publicCloudDatabase
    }

    /// iCloud is optional: the rest of the app works fine without it, so callers
    /// use this to explain why battles are unavailable instead of failing blind.
    /// Returns nil when the account is usable, otherwise the error to show. The
    /// distinction matters: a restricted account (Screen Time, MDM) must not be
    /// told to "sign in", which it cannot do.
    func availability() async -> BattleSyncError? {
        switch try? await container.accountStatus() {
        case .available:
            return nil
        case .restricted:
            return .restricted
        case .noAccount:
            return .noAccount
        default:
            return .network
        }
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

    /// Longest challenge the app ever creates is 14 days; anything beyond this
    /// cap in a fetched record is hostile or corrupt. The cap is load bearing:
    /// elapsedDayKeys enumerates every day of the challenge, and each day costs
    /// a HealthKit query and a CloudKit record, so an unchecked startDay decades
    /// in the past would turn one join into thousands of queries.
    private static let maxChallengeDays = 31

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
        // Challenge records come from the same world-writable database as
        // scores, so a record that fails validation is treated as not found.
        guard let rawName = record["name"] as? String,
              let name = sanitizedDisplayName(rawName),
              let metricRaw = record["metric"] as? String,
              let metric = BattleMetric(rawValue: metricRaw),
              let start = record["startDay"] as? Date,
              let end = record["endDay"] as? Date,
              start <= end,
              let span = Calendar.current.dateComponents([.day], from: start, to: end).day,
              span < Self.maxChallengeDays else {
            throw BattleSyncError.challengeNotFound(code)
        }
        return (name, metric, start, end)
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
            // 1 when the day includes a hand-added session (photo-backed);
            // opponents render it as the camera badge. New production field:
            // deploy the schema in the CloudKit Dashboard before release.
            record["manual"] = me.manualDays.contains(dayKey) ? 1 : 0
            return record
        }
        do {
            let (saveResults, _) = try await database.modifyRecords(
                saving: records, deleting: [], savePolicy: .allKeys, atomically: false)
            // With atomically:false a per-record failure does not throw; it
            // arrives as a Result inside saveResults. Swallowing it here would
            // mean scores silently never reach opponents, so surface the first.
            for (_, result) in saveResults {
                if case .failure(let recordError) = result {
                    throw BattleSyncError(recordError)
                }
            }
        } catch {
            throw BattleSyncError(error)
        }
    }

    /// Hard cap on participants pulled from the public database. Real battles
    /// are a handful of friends; the cap stops a hostile code holder from
    /// writing tens of thousands of score records under distinct participant
    /// IDs, which would otherwise be decoded, merged, re-encoded into SwiftData
    /// on the main actor and rendered row by row until the app runs out of
    /// memory. Once the roster is full, only scores for already-known
    /// participants are applied and pagination stops.
    static let maxParticipants = 50

    // MARK: - Proof photos and objections

    /// A treadmill proof another participant shared into the battle.
    struct ProofItem: Identifiable {
        let recordName: String
        let participantID: String
        let dayKey: String
        let steps: Int
        let distanceKm: Double
        let capturedAt: Date
        /// Local copy of the downloaded photo; nil for metadata-only fetches.
        let imageURL: URL?

        var id: String { recordName }
    }

    /// One participant's objection to another's manual day.
    struct FlagItem {
        let voterID: String
        let targetID: String
        let dayKey: String
    }

    /// Uploads my proof photos for a challenge; record names derive from the
    /// entry timestamp, so re-pushing is idempotent.
    @MainActor
    func pushProofs(for challenge: Challenge, entries: [BattleManualEntry]) async {
        guard let me = challenge.participants.first(where: \.isMe) else { return }
        let relevant = entries.filter {
            $0.day >= challenge.startDay && $0.day <= challenge.endDay
        }
        guard !relevant.isEmpty else { return }
        let records = relevant.compactMap { entry -> CKRecord? in
            guard let fileURL = ProgressPhotos.imageURL(name: entry.photoFile),
                  FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
            let name = "proof-\(challenge.code)-\(me.id)-\(Int(entry.createdAt.timeIntervalSince1970))"
            let record = CKRecord(recordType: "Proof", recordID: CKRecord.ID(recordName: name))
            record["challengeCode"] = challenge.code
            record["participantID"] = me.id
            record["dayKey"] = BattleDay.key(for: entry.day)
            record["steps"] = entry.steps
            record["distanceKm"] = entry.distanceKm
            record["capturedAt"] = entry.capturedAt
            record["photoHash"] = entry.photoHash
            record["photo"] = CKAsset(fileURL: fileURL)
            return record
        }
        _ = try? await database.modifyRecords(saving: records, deleting: [],
                                              savePolicy: .allKeys, atomically: false)
    }

    /// Proofs for one participant, photos included (gallery), or for everyone
    /// without photos (revocation math stays cheap).
    func fetchProofs(challenge: Challenge, participantID: String? = nil,
                     includePhotos: Bool) async throws -> [ProofItem] {
        var format = "challengeCode == %@"
        var arguments: [Any] = [challenge.code]
        if let participantID {
            format += " AND participantID == %@"
            arguments.append(participantID)
        }
        let query = CKQuery(recordType: "Proof",
                            predicate: NSPredicate(format: format, argumentArray: arguments))
        let operationKeys: [CKRecord.FieldKey]? = includePhotos
            ? nil
            : ["challengeCode", "participantID", "dayKey", "steps", "distanceKm", "capturedAt"]
        let page: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
        do {
            page = try await database.records(matching: query, desiredKeys: operationKeys,
                                              resultsLimit: 120)
        } catch {
            throw BattleSyncError(error)
        }
        return page.matchResults.compactMap { _, result in
            guard let record = try? result.get(),
                  let participantID = record["participantID"] as? String,
                  !participantID.isEmpty, participantID.count <= 64,
                  let dayKey = record["dayKey"] as? String,
                  BattleDay.date(for: dayKey) != nil,
                  let steps = record["steps"] as? Int,
                  let capturedAt = record["capturedAt"] as? Date else { return nil }
            var localURL: URL?
            if includePhotos, let asset = record["photo"] as? CKAsset, let assetURL = asset.fileURL {
                let target = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(record.recordID.recordName).jpg")
                try? FileManager.default.removeItem(at: target)
                try? FileManager.default.copyItem(at: assetURL, to: target)
                localURL = target
            }
            return ProofItem(
                recordName: record.recordID.recordName,
                participantID: participantID,
                dayKey: dayKey,
                steps: min(100_000, max(0, steps)),
                distanceKm: min(100, max(0, record["distanceKm"] as? Double ?? 0)),
                capturedAt: capturedAt,
                imageURL: localURL)
        }
    }

    /// My objection to a participant's manual day; one record per voter+day,
    /// so objecting twice or withdrawing stays idempotent.
    func setFlag(_ raised: Bool, challenge: Challenge, targetID: String, dayKey: String) async throws {
        let myID = PlayerIdentity.myID
        let name = "flag-\(challenge.code)-\(myID)-\(targetID)-\(dayKey)"
        do {
            if raised {
                let record = CKRecord(recordType: "Flag", recordID: CKRecord.ID(recordName: name))
                record["challengeCode"] = challenge.code
                record["voterID"] = myID
                record["targetID"] = targetID
                record["dayKey"] = dayKey
                _ = try await database.modifyRecords(saving: [record], deleting: [],
                                                     savePolicy: .allKeys, atomically: false)
            } else {
                try await database.deleteRecord(withID: CKRecord.ID(recordName: name))
            }
        } catch {
            throw BattleSyncError(error)
        }
    }

    func fetchFlags(challenge: Challenge) async throws -> [FlagItem] {
        let query = CKQuery(recordType: "Flag",
                            predicate: NSPredicate(format: "challengeCode == %@", challenge.code))
        let page: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
        do {
            page = try await database.records(matching: query, resultsLimit: 400)
        } catch {
            throw BattleSyncError(error)
        }
        return page.matchResults.compactMap { _, result in
            guard let record = try? result.get(),
                  let voterID = record["voterID"] as? String, voterID.count <= 64,
                  let targetID = record["targetID"] as? String, targetID.count <= 64,
                  let dayKey = record["dayKey"] as? String,
                  BattleDay.date(for: dayKey) != nil else { return nil }
            return FlagItem(voterID: voterID, targetID: targetID, dayKey: dayKey)
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

            // Only the deficit metric can legitimately go negative (eating more
            // than you burn); a negative step or calorie count from the public
            // database is an attack or corruption, not a score.
            let allowsNegative = challenge.metric == .deficit
            for (_, result) in page.matchResults {
                guard let record = try? result.get(),
                      let entry = SanitizedScore(record, allowsNegative: allowsNegative) else { continue }

                if let index = participants.firstIndex(where: { $0.id == entry.participantID }) {
                    // My own rows are authoritative locally; never let the
                    // public database overwrite them.
                    if !participants[index].isMe {
                        participants[index].scores[entry.dayKey] = entry.value
                        participants[index].name = entry.name
                        participants[index].manualDays.removeAll { $0 == entry.dayKey }
                        if entry.manual {
                            participants[index].manualDays.append(entry.dayKey)
                        }
                    }
                } else if participants.count < Self.maxParticipants {
                    participants.append(ParticipantScore(
                        id: entry.participantID, name: entry.name, isMe: false,
                        scores: [entry.dayKey: entry.value],
                        manualDays: entry.manual ? [entry.dayKey] : []))
                }
            }
            // Stop paging once the roster is full: further pages can only add
            // participants we are now refusing anyway.
            cursor = participants.count < Self.maxParticipants ? page.queryCursor : nil
        } while cursor != nil

        challenge.participants = participants
    }
}

/// Strips control characters, trims, and caps a display name from the public
/// database; nil when nothing legible remains. Both challenge names and
/// participant names pass through here, so hostile records cannot inject
/// newlines or BiDi overrides into the leaderboard, nav title, or share text.
private func sanitizedDisplayName(_ raw: String) -> String? {
    let cleaned = String(raw.unicodeScalars
        .filter { !CharacterSet.controlCharacters.contains($0) }
        .prefix(40))
        .trimmingCharacters(in: .whitespaces)
    return cleaned.isEmpty ? nil : cleaned
}

/// The public database is writable by anyone with the join code, so every field
/// is treated as untrusted input: names are stripped of control characters and
/// capped, ids and day keys are length-checked, scores clamped to a plausible range.
private struct SanitizedScore {
    let participantID: String
    let name: String
    let dayKey: String
    let value: Double
    let manual: Bool

    init?(_ record: CKRecord, allowsNegative: Bool) {
        guard let participantID = record["participantID"] as? String,
              let rawName = record["participantName"] as? String,
              let dayKey = record["dayKey"] as? String,
              let rawValue = record["value"] as? Double else { return nil }

        guard let name = sanitizedDisplayName(rawName),
              !participantID.isEmpty, participantID.count <= 64,
              BattleDay.date(for: dayKey) != nil,
              rawValue.isFinite else { return nil }

        self.participantID = participantID
        self.name = name
        self.dayKey = dayKey
        self.value = min(500_000, max(allowsNegative ? -500_000 : 0, rawValue))
        // Records from before the field existed have no "manual" key.
        self.manual = (record["manual"] as? Int ?? 0) == 1
    }
}

#endif
