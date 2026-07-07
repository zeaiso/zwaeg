import Foundation
import SwiftData

enum BattleMetric: String, Codable, CaseIterable, Identifiable {
    case steps
    case activeKcal
    case deficit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .steps: return "Schritte"
        case .activeKcal: return "Aktivkalorien"
        case .deficit: return "Kaloriendefizit"
        }
    }

    var detail: String {
        switch self {
        case .steps: return "Wer geht am meisten?"
        case .activeKcal: return "Wer verbrennt am meisten?"
        case .deficit: return "Wer spart am meisten Kalorien ein?"
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
        case .steps: return "Schritte"
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
