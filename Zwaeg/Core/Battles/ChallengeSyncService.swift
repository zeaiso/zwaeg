import Foundation
import CloudKit

enum AppConfig {
    /// Flip to true once the paid Apple Developer account and the iCloud
    /// entitlement (project.yml) are set up. Until then battles run locally
    /// against demo opponents.
    static let cloudKitEnabled = false
}

/// Pushes my scores and pulls the other participants' scores for a challenge.
protocol ChallengeSyncService {
    func refresh(_ challenge: Challenge) async
}

enum ChallengeSync {
    static var live: ChallengeSyncService {
        AppConfig.cloudKitEnabled ? CloudKitChallengeService() : LocalChallengeService()
    }
}

// MARK: - Local mode: stable demo opponents

struct LocalChallengeService: ChallengeSyncService {
    func refresh(_ challenge: Challenge) async {
        var participants = challenge.participants
        for index in participants.indices where !participants[index].isMe {
            for dayKey in challenge.elapsedDayKeys {
                participants[index].scores[dayKey] = BattleScoreEngine.botScore(
                    metric: challenge.metric,
                    challengeCode: challenge.code,
                    botName: participants[index].name,
                    dayKey: dayKey)
            }
        }
        challenge.participants = participants
    }
}

// MARK: - CloudKit mode: join-code based sync via the public database

/// Record types: "Challenge" (code, name, metric, startDay, endDay) and
/// "Score" (challengeCode, participantID, participantName, dayKey, value).
/// Participants find each other purely via the 6-character join code.
struct CloudKitChallengeService: ChallengeSyncService {
    private var database: CKDatabase {
        CKContainer.default().publicCloudDatabase
    }

    func refresh(_ challenge: Challenge) async {
        guard AppConfig.cloudKitEnabled else { return }
        await pushMyScores(challenge)
        await pullAllScores(challenge)
    }

    func publish(_ challenge: Challenge) async throws {
        let record = CKRecord(recordType: "Challenge",
                              recordID: CKRecord.ID(recordName: "challenge-\(challenge.code)"))
        record["code"] = challenge.code
        record["name"] = challenge.name
        record["metric"] = challenge.metricRaw
        record["startDay"] = challenge.startDay
        record["endDay"] = challenge.endDay
        try await database.save(record)
    }

    func fetchChallenge(code: String) async throws -> (name: String, metric: BattleMetric, start: Date, end: Date)? {
        let recordID = CKRecord.ID(recordName: "challenge-\(code)")
        guard let record = try? await database.record(for: recordID),
              let name = record["name"] as? String,
              let metricRaw = record["metric"] as? String,
              let metric = BattleMetric(rawValue: metricRaw),
              let start = record["startDay"] as? Date,
              let end = record["endDay"] as? Date else {
            return nil
        }
        return (name, metric, start, end)
    }

    private func pushMyScores(_ challenge: Challenge) async {
        guard let me = challenge.participants.first(where: \.isMe) else { return }
        for (dayKey, value) in me.scores {
            let recordID = CKRecord.ID(recordName: "score-\(challenge.code)-\(me.id)-\(dayKey)")
            let record = (try? await database.record(for: recordID))
                ?? CKRecord(recordType: "Score", recordID: recordID)
            record["challengeCode"] = challenge.code
            record["participantID"] = me.id
            record["participantName"] = me.name
            record["dayKey"] = dayKey
            record["value"] = value
            try? await database.save(record)
        }
    }

    private func pullAllScores(_ challenge: Challenge) async {
        let predicate = NSPredicate(format: "challengeCode == %@", challenge.code)
        let query = CKQuery(recordType: "Score", predicate: predicate)
        guard let results = try? await database.records(matching: query, resultsLimit: 500) else { return }

        var participants = challenge.participants
        for (_, result) in results.matchResults {
            guard let record = try? result.get(),
                  let participantID = record["participantID"] as? String,
                  let participantName = record["participantName"] as? String,
                  let dayKey = record["dayKey"] as? String,
                  let value = record["value"] as? Double else { continue }

            // The public database is untrusted: cap name length, drop
            // control characters and clamp scores to plausible ranges.
            let cleanName = String(participantName.unicodeScalars
                .filter { !CharacterSet.controlCharacters.contains($0) }
                .prefix(40))
            let cleanValue = min(500_000, max(0, value))
            guard !cleanName.isEmpty, participantID.count <= 64, dayKey.count <= 16 else { continue }

            if let index = participants.firstIndex(where: { $0.id == participantID }) {
                if !participants[index].isMe {
                    participants[index].scores[dayKey] = cleanValue
                }
            } else {
                participants.append(ParticipantScore(
                    id: participantID, name: cleanName, isMe: false,
                    scores: [dayKey: cleanValue]))
            }
        }
        challenge.participants = participants
    }
}
