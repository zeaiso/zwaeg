// The battles FEATURE is opt-in at build time (see Config/Battles.yml), but the
// models here compile in every configuration on purpose: if Challenge left the
// SwiftData schema whenever ZWAEG_BATTLES is off, opening an existing store with
// a battles-off build would migrate the entity away and destroy local battle
// data. Only the CloudKit sync and the UI are behind the flag.

import Foundation
import SwiftData

enum BattleMetric: String, Codable, CaseIterable, Identifiable {
    case steps
    case activeKcal
    case deficit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .steps: return "Schritte".loc
        case .activeKcal: return "Aktivkalorien".loc
        case .deficit: return "Kaloriendefizit".loc
        }
    }

    var detail: String {
        switch self {
        case .steps: return "Wer geht am meisten?".loc
        case .activeKcal: return "Wer verbrennt am meisten?".loc
        case .deficit: return "Wer spart am meisten Kalorien ein?".loc
        }
    }

    var symbol: String {
        switch self {
        case .steps: return "figure.walk"
        case .activeKcal: return "flame.fill"
        case .deficit: return "arrow.down.circle.fill"
        }
    }

    var unit: String {
        switch self {
        case .steps: return "Schritte".loc
        case .activeKcal, .deficit: return "kcal"
        }
    }
}

/// One person in a challenge with their per-day scores.
struct ParticipantScore: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var isMe: Bool
    /// Day key ("yyyy-MM-dd") to metric value.
    var scores: [String: Double]

    var total: Double {
        scores.values.reduce(0, +)
    }
}

@Model
final class Challenge {
    @Attribute(.unique) var code: String
    var name: String
    var metricRaw: String
    var startDay: Date
    var endDay: Date
    var createdAt: Date
    /// JSON-encoded [ParticipantScore]; kept as Data for painless SwiftData storage
    /// and 1:1 mapping onto the CloudKit record later.
    var participantsData: Data

    init(code: String, name: String, metric: BattleMetric, startDay: Date, endDay: Date,
         participants: [ParticipantScore]) {
        self.code = code
        self.name = name
        self.metricRaw = metric.rawValue
        self.startDay = Calendar.current.startOfDay(for: startDay)
        self.endDay = Calendar.current.startOfDay(for: endDay)
        self.createdAt = .now
        self.participantsData = (try? JSONEncoder().encode(participants)) ?? Data()
    }

    var metric: BattleMetric {
        BattleMetric(rawValue: metricRaw) ?? .steps
    }

    var participants: [ParticipantScore] {
        get { (try? JSONDecoder().decode([ParticipantScore].self, from: participantsData)) ?? [] }
        set { participantsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var isActive: Bool {
        Calendar.current.startOfDay(for: .now) <= endDay
    }

    var daysLeft: Int {
        max(0, (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: endDay).day ?? 0) + 1)
    }

    var ranking: [ParticipantScore] {
        participants.sorted { $0.total > $1.total }
    }

    var myRank: Int? {
        ranking.firstIndex(where: \.isMe).map { $0 + 1 }
    }

    /// Days of the challenge up to and including today.
    var elapsedDayKeys: [String] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var keys: [String] = []
        var day = startDay
        while day <= min(today, endDay) {
            keys.append(BattleDay.key(for: day))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return keys
    }
}

enum BattleDay {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()

    static func key(for date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(for key: String) -> Date? {
        formatter.date(from: key).map { Calendar.current.startOfDay(for: $0) }
    }
}

extension Challenge {
    /// Join code of the -seed-profile demo battle. Challenges with this code
    /// never touch CloudKit (BattlesScreen skips them during sync): the code is
    /// shared by every seeded install, so syncing it would merge all testers
    /// into one leaderboard on the real public database.
    static let demoCode = "DEMO42"

    /// A freshly created or joined challenge containing only me. Create and
    /// join build the identical participant; keeping the shape here stops the
    /// two sheets drifting apart (join once shipped a literal "Du" as the name
    /// every opponent saw).
    static func mine(code: String, name: String, metric: BattleMetric,
                     startDay: Date, endDay: Date, profile: UserProfile) -> Challenge {
        Challenge(code: code, name: name, metric: metric,
                  startDay: startDay, endDay: endDay,
                  participants: [ParticipantScore(
                      id: PlayerIdentity.myID,
                      name: profile.battleName,
                      isMe: true,
                      scores: [:])])
    }
}

enum PlayerIdentity {
    private static let key = "playerIdentity"

    /// Stable anonymous id keying every CloudKit score record, created once per
    /// install. Deliberately not tied to any Apple Account: battles know
    /// players only by this UUID and their chosen display name.
    static var myID: String {
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }
}
