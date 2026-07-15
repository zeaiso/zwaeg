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

    /// Ambiguous glyphs (0/O, 1/I) are left out so codes survive being read
    /// aloud or typed from a screenshot.
    static func makeCode() -> String {
        let alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).compactMap { _ in alphabet.randomElement() })
    }
}
