import Foundation
import SwiftData

// MARK: - Enums

enum Sex: String, Codable, CaseIterable, Identifiable {
    case male, female

    var id: String { rawValue }

    var label: String {
        switch self {
        case .male: return "Männlich"
        case .female: return "Weiblich"
        }
    }

    var symbol: String {
        switch self {
        case .male: return "figure.stand"
        case .female: return "figure.stand.dress"
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary, light, moderate, active, veryActive

    var id: String { rawValue }

    /// Physical Activity Level multiplier for TDEE.
    var pal: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }

    var label: String {
        switch self {
        case .sedentary: return "Kaum aktiv"
        case .light: return "Leicht aktiv"
        case .moderate: return "Mässig aktiv"
        case .active: return "Sehr aktiv"
        case .veryActive: return "Extrem aktiv"
        }
    }

    var detail: String {
        switch self {
        case .sedentary: return "Bürojob, wenig Bewegung"
        case .light: return "Leichte Bewegung, 1-2× Sport pro Woche"
        case .moderate: return "Regelmässig aktiv, 3-5× Sport pro Woche"
        case .active: return "Täglich Sport oder körperliche Arbeit"
        case .veryActive: return "Harte körperliche Arbeit und intensiver Sport"
        }
    }
}

enum Goal: String, Codable, CaseIterable, Identifiable {
    case lose, maintain, gain

    var id: String { rawValue }

    /// Daily kcal adjustment applied to TDEE.
    var calorieAdjustment: Int {
        switch self {
        case .lose: return -500
        case .maintain: return 0
        case .gain: return 300
        }
    }

    var label: String {
        switch self {
        case .lose: return "Abnehmen"
        case .maintain: return "Gewicht halten"
        case .gain: return "Zunehmen"
        }
    }

    var symbol: String {
        switch self {
        case .lose: return "arrow.down.circle.fill"
        case .maintain: return "equal.circle.fill"
        case .gain: return "arrow.up.circle.fill"
        }
    }
}

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var label: String {
        switch self {
        case .breakfast: return "Frühstück"
        case .lunch: return "Mittagessen"
        case .dinner: return "Abendessen"
        case .snack: return "Snacks"
        }
    }

    var symbol: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "carrot.fill"
        }
    }
}

// MARK: - SwiftData models

@Model
final class UserProfile {
    var name: String
    var sexRaw: String
    var age: Int
    var heightCm: Double
    var weightKg: Double
    var activityRaw: String
    var goalRaw: String
    var dailyCalorieTarget: Int
    var createdAt: Date

    init(name: String, sex: Sex, age: Int, heightCm: Double, weightKg: Double,
         activity: ActivityLevel, goal: Goal) {
        self.name = name
        self.sexRaw = sex.rawValue
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityRaw = activity.rawValue
        self.goalRaw = goal.rawValue
        self.createdAt = .now
        self.dailyCalorieTarget = CalorieMath.dailyTarget(
            sex: sex, weightKg: weightKg, heightCm: heightCm, age: age,
            activity: activity, goal: goal)
    }

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }

    var activity: ActivityLevel {
        get { ActivityLevel(rawValue: activityRaw) ?? .moderate }
        set { activityRaw = newValue.rawValue }
    }

    var goal: Goal {
        get { Goal(rawValue: goalRaw) ?? .maintain }
        set { goalRaw = newValue.rawValue }
    }

    var bmi: Double {
        CalorieMath.bmi(weightKg: weightKg, heightCm: heightCm)
    }

    func recalculateTarget() {
        dailyCalorieTarget = CalorieMath.dailyTarget(
            sex: sex, weightKg: weightKg, heightCm: heightCm, age: age,
            activity: activity, goal: goal)
    }
}

@Model
final class FoodEntry {
    /// Start of the day this entry belongs to.
    var day: Date
    var mealRaw: String
    var name: String
    var calories: Int
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var createdAt: Date

    init(day: Date, meal: MealType, name: String, calories: Int,
         proteinG: Double = 0, carbsG: Double = 0, fatG: Double = 0) {
        self.day = Calendar.current.startOfDay(for: day)
        self.mealRaw = meal.rawValue
        self.name = name
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.createdAt = .now
    }

    var meal: MealType {
        get { MealType(rawValue: mealRaw) ?? .snack }
        set { mealRaw = newValue.rawValue }
    }
}

@Model
final class WaterDay {
    @Attribute(.unique) var day: Date
    var glasses: Int

    init(day: Date, glasses: Int = 0) {
        self.day = Calendar.current.startOfDay(for: day)
        self.glasses = glasses
    }
}

@Model
final class WeightEntry {
    var date: Date
    var weightKg: Double

    init(date: Date = .now, weightKg: Double) {
        self.date = date
        self.weightKg = weightKg
    }
}
