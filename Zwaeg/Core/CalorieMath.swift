import SwiftUI

/// Pure calculation engine: BMI, ideal weight, calorie needs and expenditure.
/// Kept free of UI and persistence so the battle/challenge scoring can reuse it later.
enum CalorieMath {

    // MARK: - BMI

    static func bmi(weightKg: Double, heightCm: Double) -> Double {
        let meters = heightCm / 100
        guard meters > 0 else { return 0 }
        return weightKg / (meters * meters)
    }

    enum BMICategory: CaseIterable {
        case underweight, normal, overweight, obese1, obese2, obese3

        var label: String {
            switch self {
            case .underweight: return "Untergewicht".loc
            case .normal: return "Normalgewicht".loc
            case .overweight: return "Übergewicht".loc
            case .obese1: return "Adipositas Grad I".loc
            case .obese2: return "Adipositas Grad II".loc
            case .obese3: return "Adipositas Grad III".loc
            }
        }

        var color: Color {
            switch self {
            case .underweight: return .blue
            case .normal: return .green
            case .overweight: return .yellow
            case .obese1: return .orange
            case .obese2: return .red
            case .obese3: return Color(red: 0.6, green: 0.05, blue: 0.05)
            }
        }
    }

    static func bmiCategory(_ bmi: Double) -> BMICategory {
        switch bmi {
        case ..<18.5: return .underweight
        case ..<25: return .normal
        case ..<30: return .overweight
        case ..<35: return .obese1
        case ..<40: return .obese2
        default: return .obese3
        }
    }

    /// Weight range (kg) corresponding to BMI 18.5-24.9.
    static func healthyWeightRange(heightCm: Double) -> ClosedRange<Double> {
        let m2 = (heightCm / 100) * (heightCm / 100)
        return (18.5 * m2)...(24.9 * m2)
    }

    // MARK: - Ideal weight formulas

    struct IdealWeightResult: Identifiable {
        let id = UUID()
        let formula: String
        let weightKg: Double
    }

    static func idealWeights(sex: Sex, heightCm: Double) -> [IdealWeightResult] {
        let inchesOver5Ft = max(0, heightCm / 2.54 - 60)
        let devine = sex == .male ? 50 + 2.3 * inchesOver5Ft : 45.5 + 2.3 * inchesOver5Ft
        let robinson = sex == .male ? 52 + 1.9 * inchesOver5Ft : 49 + 1.7 * inchesOver5Ft
        let miller = sex == .male ? 56.2 + 1.41 * inchesOver5Ft : 53.1 + 1.36 * inchesOver5Ft
        let broca = (heightCm - 100) * (sex == .male ? 0.9 : 0.85)
        return [
            IdealWeightResult(formula: "Devine", weightKg: devine),
            IdealWeightResult(formula: "Robinson", weightKg: robinson),
            IdealWeightResult(formula: "Miller", weightKg: miller),
            IdealWeightResult(formula: "Broca (angepasst)", weightKg: broca),
        ]
    }

    static func idealWeightRange(sex: Sex, heightCm: Double) -> ClosedRange<Double> {
        let values = idealWeights(sex: sex, heightCm: heightCm).map(\.weightKg)
        return (values.min() ?? 0)...(values.max() ?? 0)
    }

    // MARK: - Calorie needs (Mifflin-St Jeor)

    /// Basal metabolic rate in kcal/day.
    static func bmr(sex: Sex, weightKg: Double, heightCm: Double, age: Int) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }

    /// Total daily energy expenditure in kcal/day.
    static func tdee(sex: Sex, weightKg: Double, heightCm: Double, age: Int,
                     activity: ActivityLevel) -> Double {
        bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age) * activity.pal
    }

    /// Daily calorie target for a goal, clamped to a safe minimum.
    static func dailyTarget(sex: Sex, weightKg: Double, heightCm: Double, age: Int,
                            activity: ActivityLevel, goal: Goal) -> Int {
        let expenditure = tdee(sex: sex, weightKg: weightKg, heightCm: heightCm,
                               age: age, activity: activity)
        let minimum: Double = sex == .male ? 1500 : 1200
        return Int(max(minimum, expenditure + Double(goal.calorieAdjustment)).rounded())
    }

    // MARK: - Calorie expenditure (MET)

    struct METActivity: Identifiable, Hashable {
        var id: String { name }
        let name: String
        let symbol: String
        let met: Double
    }

    static let activities: [METActivity] = [
        METActivity(name: "Gehen", symbol: "figure.walk", met: 3.5),
        METActivity(name: "Wandern", symbol: "figure.hiking", met: 6.0),
        METActivity(name: "Joggen", symbol: "figure.run", met: 7.0),
        METActivity(name: "Laufen (schnell)", symbol: "figure.run.circle", met: 9.8),
        METActivity(name: "Radfahren", symbol: "figure.outdoor.cycle", met: 6.8),
        METActivity(name: "Radfahren (zügig)", symbol: "bicycle", met: 8.5),
        METActivity(name: "Schwimmen", symbol: "figure.pool.swim", met: 6.0),
        METActivity(name: "Krafttraining", symbol: "dumbbell.fill", met: 5.0),
        METActivity(name: "HIIT", symbol: "flame.fill", met: 8.0),
        METActivity(name: "Yoga", symbol: "figure.mind.and.body", met: 2.5),
        METActivity(name: "Fussball", symbol: "soccerball", met: 7.0),
        METActivity(name: "Tennis", symbol: "tennisball.fill", met: 7.3),
        METActivity(name: "Tanzen", symbol: "figure.dance", met: 4.5),
        METActivity(name: "Skifahren", symbol: "figure.skiing.downhill", met: 7.0),
        METActivity(name: "Treppensteigen", symbol: "figure.stairs", met: 8.0),
        METActivity(name: "Putzen", symbol: "bubbles.and.sparkles", met: 3.3),
    ]

    static func kcalBurned(met: Double, weightKg: Double, minutes: Double) -> Double {
        met * weightKg * (minutes / 60)
    }
}
