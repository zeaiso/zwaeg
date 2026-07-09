import Foundation
import SwiftData

// MARK: - Enums

enum Sex: String, Codable, CaseIterable, Identifiable {
    case male, female

    var id: String { rawValue }

    var label: String {
        switch self {
        case .male: return "Männlich".loc
        case .female: return "Weiblich".loc
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
        case .sedentary: return "Kaum aktiv".loc
        case .light: return "Leicht aktiv".loc
        case .moderate: return "Mäßig aktiv".loc
        case .active: return "Sehr aktiv".loc
        case .veryActive: return "Extrem aktiv".loc
        }
    }

    var detail: String {
        switch self {
        case .sedentary: return "Bürojob, wenig Bewegung".loc
        case .light: return "Leichte Bewegung, 1-2× Sport pro Woche".loc
        case .moderate: return "Regelmäßig aktiv, 3-5× Sport pro Woche".loc
        case .active: return "Täglich Sport oder körperliche Arbeit".loc
        case .veryActive: return "Harte körperliche Arbeit und intensiver Sport".loc
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
        case .lose: return "Abnehmen".loc
        case .maintain: return "Gewicht halten".loc
        case .gain: return "Zunehmen".loc
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
        case .breakfast: return "Frühstück".loc
        case .lunch: return "Mittagessen".loc
        case .dinner: return "Abendessen".loc
        case .snack: return "Snacks".loc
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

    /// Dative form for buttons like "Zum Frühstück hinzufügen".
    var addLabel: String {
        switch self {
        case .breakfast: return "Zum Frühstück hinzufügen".loc
        case .lunch: return "Zum Mittagessen hinzufügen".loc
        case .dinner: return "Zum Abendessen hinzufügen".loc
        case .snack: return "Zu den Snacks hinzufügen".loc
        }
    }
}

enum Mood: String, Codable, CaseIterable, Identifiable {
    case great, good, okay, low, bad

    var id: String { rawValue }

    /// Weather metaphor, SF Symbols (color emoji doesn't render in the simulator).
    var symbol: String {
        switch self {
        case .great: return "sun.max.fill"
        case .good: return "cloud.sun.fill"
        case .okay: return "cloud.fill"
        case .low: return "cloud.rain.fill"
        case .bad: return "cloud.bolt.rain.fill"
        }
    }

    var label: String {
        switch self {
        case .great: return "Super".loc
        case .good: return "Gut".loc
        case .okay: return "Okay".loc
        case .low: return "Mäßig".loc
        case .bad: return "Mies".loc
        }
    }
}

enum FastingPlan: String, Codable, CaseIterable, Identifiable {
    case sixteenEight, fourteenTen, twelveTwelve

    var id: String { rawValue }

    var fastingHours: Int {
        switch self {
        case .sixteenEight: return 16
        case .fourteenTen: return 14
        case .twelveTwelve: return 12
        }
    }

    var label: String {
        switch self {
        case .sixteenEight: return "16:8"
        case .fourteenTen: return "14:10"
        case .twelveTwelve: return "12:12"
        }
    }

    var detail: String {
        switch self {
        case .sixteenEight: return "16 Std. fasten, 8 Std. essen".loc
        case .fourteenTen: return "14 Std. fasten, 10 Std. essen".loc
        case .twelveTwelve: return "12 Std. fasten, 12 Std. essen".loc
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
    var buddyRaw: String = ""
    /// Daily water goal in glasses of 2.5 dl; 8 glasses = 2 liters.
    var waterGoalGlasses: Int = 8

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

    var buddy: Buddy {
        get { Buddy.decode(buddyRaw) ?? Buddy.seeded(name.isEmpty ? "zwaeg" : name) }
        set { buddyRaw = newValue.encoded }
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
final class DayNote {
    @Attribute(.unique) var day: Date
    /// Empty string means no mood picked yet.
    var moodRaw: String
    var text: String

    init(day: Date, mood: Mood? = nil, text: String = "") {
        self.day = Calendar.current.startOfDay(for: day)
        self.moodRaw = mood?.rawValue ?? ""
        self.text = text
    }

    var mood: Mood? {
        get { Mood(rawValue: moodRaw) }
        set { moodRaw = newValue?.rawValue ?? "" }
    }
}

@Model
final class FastingSession {
    var start: Date
    var planRaw: String
    var endedAt: Date?

    init(start: Date = .now, plan: FastingPlan) {
        self.start = start
        self.planRaw = plan.rawValue
        self.endedAt = nil
    }

    var plan: FastingPlan {
        get { FastingPlan(rawValue: planRaw) ?? .sixteenEight }
        set { planRaw = newValue.rawValue }
    }

    var goalEnd: Date {
        start.addingTimeInterval(TimeInterval(plan.fastingHours) * 3600)
    }

    var isActive: Bool { endedAt == nil }
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
