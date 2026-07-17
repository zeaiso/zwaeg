import Foundation

/// Which meals the user actually eats (all calories at lunch, lunch and
/// dinner only, ...). Hidden meals disappear from the diary and the meal
/// pickers, and the daily calorie budget redistributes over the enabled ones.
/// Stored as comma-joined raw values under `storageKey`; an empty string
/// means everything is enabled.
enum MealPlan {
    static let storageKey = "enabledMeals"

    /// Base share of the daily budget when all meals are enabled.
    private static let weights: [MealType: Double] = [
        .breakfast: 0.25, .lunch: 0.35, .dinner: 0.30, .snack: 0.10,
    ]

    static func enabled(from raw: String) -> [MealType] {
        let set = Set(raw.split(separator: ",").compactMap { MealType(rawValue: String($0)) })
        let meals = MealType.allCases.filter(set.contains)
        return meals.isEmpty ? MealType.allCases : meals
    }

    static func rawValue(_ meals: [MealType]) -> String {
        meals.map(\.rawValue).joined(separator: ",")
    }

    /// Share of the daily budget for one meal, renormalized over the enabled
    /// meals: lunch alone gets everything, lunch plus dinner split 54/46.
    /// A disabled meal that still shows (old entries) keeps its base share.
    static func budgetShare(_ meal: MealType, enabled: [MealType]) -> Double {
        let pool = enabled.contains(meal) ? enabled : MealType.allCases
        let total = pool.reduce(0) { $0 + (weights[$1] ?? 0) }
        guard total > 0 else { return 0 }
        return (weights[meal] ?? 0) / total
    }
}
