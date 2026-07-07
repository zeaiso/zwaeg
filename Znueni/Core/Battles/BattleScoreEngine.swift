import Foundation

/// Computes my daily battle score from diary and Apple Health data,
/// and generates stable demo-opponent scores while CloudKit is off.
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

    // MARK: - Demo opponents (local mode)

    static let botNames = ["Luca", "Mia", "Noah"]

    /// Deterministic pseudo-random score so bots stay consistent across launches.
    static func botScore(metric: BattleMetric, challengeCode: String, botName: String, dayKey: String) -> Double {
        let fraction = stableFraction("\(challengeCode)|\(botName)|\(dayKey)")
        switch metric {
        case .steps:
            return (4000 + fraction * 10000).rounded()
        case .activeKcal:
            return (150 + fraction * 550).rounded()
        case .deficit:
            return (fraction * 800 - 100).rounded()
        }
    }

    /// djb2 hash mapped to 0..<1; Swift's Hasher is seeded per launch, so not used here.
    private static func stableFraction(_ text: String) -> Double {
        var hash: UInt64 = 5381
        for byte in text.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return Double(hash % 10_000) / 10_000
    }

    static func makeCode() -> String {
        let alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).compactMap { _ in alphabet.randomElement() })
    }
}
