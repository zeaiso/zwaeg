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
        case .moderate: return "Mässig aktiv".loc
        case .active: return "Sehr aktiv".loc
        case .veryActive: return "Extrem aktiv".loc
        }
    }

    var detail: String {
        switch self {
        case .sedentary: return "Bürojob, wenig Bewegung".loc
        case .light: return "Leichte Bewegung, 1-2× Sport pro Woche".loc
        case .moderate: return "Regelmässig aktiv, 3-5× Sport pro Woche".loc
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
        case .low: return "Mässig".loc
        case .bad: return "Mies".loc
        }
    }
}

enum FastingLevel: CaseIterable, Identifiable {
    case beginner, intermediate, advanced

    var id: Self { self }

    var label: String {
        switch self {
        case .beginner: return "Einsteiger".loc
        case .intermediate: return "Fortgeschritten".loc
        case .advanced: return "Profi".loc
        }
    }
}

enum FastingPlan: String, Codable, CaseIterable, Identifiable {
    case twelveTwelve, fourteenTen, fifteenNine, sixteenEight
    case eighteenSix, nineteenFive
    case twentyFour, twentyTwoTwo, twentyThreeOne

    var id: String { rawValue }

    var fastingHours: Int {
        switch self {
        case .twelveTwelve: return 12
        case .fourteenTen: return 14
        case .fifteenNine: return 15
        case .sixteenEight: return 16
        case .eighteenSix: return 18
        case .nineteenFive: return 19
        case .twentyFour: return 20
        case .twentyTwoTwo: return 22
        case .twentyThreeOne: return 23
        }
    }

    var label: String {
        "\(fastingHours):\(24 - fastingHours)"
    }

    var detail: String {
        "%d Std. fasten, %d Std. essen".loc(fastingHours, 24 - fastingHours)
    }

    var level: FastingLevel {
        switch self {
        case .twelveTwelve, .fourteenTen, .fifteenNine, .sixteenEight: return .beginner
        case .eighteenSix, .nineteenFive: return .intermediate
        case .twentyFour, .twentyTwoTwo, .twentyThreeOne: return .advanced
        }
    }

    var emoji: String {
        switch self {
        case .twelveTwelve: return "🐣"
        case .fourteenTen: return "🐰"
        case .fifteenNine: return "🐨"
        case .sixteenEight: return "🦊"
        case .eighteenSix: return "🦉"
        case .nineteenFive: return "🐮"
        case .twentyFour: return "🐺"
        case .twentyTwoTwo: return "🐼"
        case .twentyThreeOne: return "🐸"
        }
    }

    /// SF Symbol stand-in for runtimes without the emoji font.
    var symbol: String {
        switch level {
        case .beginner: return "leaf.fill"
        case .intermediate: return "flame.fill"
        case .advanced: return "bolt.fill"
        }
    }
}

/// What the body is doing after a given number of fasted hours.
enum FastingStage: Int, CaseIterable, Identifiable {
    case bloodSugarUp, bloodSugarDown, settling, fatBurn, autophagy

    var id: Int { rawValue }

    var startHour: Int {
        switch self {
        case .bloodSugarUp: return 0
        case .bloodSugarDown: return 3
        case .settling: return 8
        case .fatBurn: return 12
        case .autophagy: return 16
        }
    }

    var name: String {
        switch self {
        case .bloodSugarUp: return "Blutzucker steigt".loc
        case .bloodSugarDown: return "Blutzucker sinkt".loc
        case .settling: return "Blutzucker stabil".loc
        case .fatBurn: return "Fettverbrennung".loc
        case .autophagy: return "Autophagie".loc
        }
    }

    var info: String {
        switch self {
        case .bloodSugarUp: return "Der Körper verdaut die letzte Mahlzeit, der Blutzucker steigt an.".loc
        case .bloodSugarDown: return "Der Blutzucker sinkt, der Körper nutzt die Zuckerspeicher.".loc
        case .settling: return "Die Speicher sind fast leer, der Körper stellt auf Fett um.".loc
        case .fatBurn: return "Der Körper gewinnt seine Energie jetzt vor allem aus Fett.".loc
        case .autophagy: return "Die Zellen räumen auf und recyceln alte Bestandteile.".loc
        }
    }

    var emoji: String {
        switch self {
        case .bloodSugarUp: return "🍬"
        case .bloodSugarDown: return "📉"
        case .settling: return "⚖️"
        case .fatBurn: return "🔥"
        case .autophagy: return "✨"
        }
    }

    var symbol: String {
        switch self {
        case .bloodSugarUp: return "chart.line.uptrend.xyaxis"
        case .bloodSugarDown: return "chart.line.downtrend.xyaxis"
        case .settling: return "equal.circle.fill"
        case .fatBurn: return "flame.fill"
        case .autophagy: return "sparkles"
        }
    }

    var rangeLabel: String {
        if let next = FastingStage(rawValue: rawValue + 1) {
            return "%d-%d Std.".loc(startHour, next.startHour)
        }
        return "ab %d Std.".loc(startHour)
    }

    static func current(elapsedHours: Double) -> FastingStage {
        allCases.last { Double($0.startHour) <= elapsedHours } ?? .bloodSugarUp
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
