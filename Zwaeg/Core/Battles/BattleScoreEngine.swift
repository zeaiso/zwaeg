// Battles are opt-in at build time: they need CloudKit and therefore a paid
// Apple Developer account. See Config/Battles.yml and docs/DEVELOPMENT.md.
#if ZWAEG_BATTLES

import Foundation

/// Computes my daily battle score from diary and Apple Health data.
enum BattleScoreEngine {

    /// My score for one day. Deficit = (BMR + active energy) - eaten, so it
    /// rewards both moving more and eating less.
    static func myScore(metric: BattleMetric, profile: UserProfile,
                        consumedKcal: Int, activity: HealthKitService.DayActivity) -> Double {
        switch metric {
        case .steps:
            return Double(activity.steps)
        case .activeKcal:
            return Double(activity.activeKcal)
        case .deficit:
            let bmr = CalorieMath.bmr(sex: profile.sex, weightKg: profile.weightKg,
                                      heightCm: profile.heightCm, age: profile.age)
            return (bmr + Double(activity.activeKcal)) - Double(consumedKcal)
        }
    }

    /// Recomputes and stores my score for every elapsed challenge day. Lives
    /// here rather than in a view so joining can compute and push scores
    /// immediately; without that, the challenge creator would not see a new
    /// participant until the joiner's next manual refresh.
    @MainActor
    static func updateMyScores(for challenge: Challenge, profile: UserProfile,
                               caloriesByDay: [Date: Int]) async {
        var participants = challenge.participants
        guard let myIndex = participants.firstIndex(where: \.isMe) else { return }
        for dayKey in challenge.elapsedDayKeys {
            guard let day = BattleDay.date(for: dayKey) else { continue }
            let activity = HealthKitService.shared.isConnected
                ? await HealthKitService.shared.activity(for: day)
                : HealthKitService.DayActivity()
            participants[myIndex].scores[dayKey] = myScore(
                metric: challenge.metric, profile: profile,
                consumedKcal: caloriesByDay[day] ?? 0, activity: activity)
        }
        challenge.participants = participants
    }

    /// One pass over the diary instead of one filter per challenge day.
    static func caloriesByDay(_ entries: [FoodEntry]) -> [Date: Int] {
        entries.reduce(into: [:]) { $0[$1.day, default: 0] += $1.calories }
    }

    // MARK: - Join codes

    /// Ambiguous glyphs (0/O, 1/I) are left out so codes survive being read
    /// aloud or typed from a screenshot.
    private static let codeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    private static let codeLength = 6

    static func makeCode() -> String {
        String((0..<codeLength).compactMap { _ in codeAlphabet.randomElement() })
    }

    /// Validation mirrors generation: a code containing 0/O/1/I can never have
    /// been issued, so it is rejected locally instead of after a network trip.
    static func isValidCode(_ code: String) -> Bool {
        code.count == codeLength && code.allSatisfy { codeAlphabet.contains($0) }
    }
}

#endif
