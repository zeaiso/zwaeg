import Foundation

/// A food item with nutrition values per 100 g, from a barcode lookup or the bundled Swiss database.
struct FoodProduct: Identifiable, Hashable {
    enum Source: String {
        case openFoodFacts
        case swissDatabase
        case custom
    }

    let id: String
    let name: String
    let brand: String?
    let kcalPer100g: Double
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
    let barcode: String?
    let source: Source
    /// Grams per serving when the source provides it; UI falls back to 100 g.
    var servingGrams: Double? = nil
    /// Beyond the macros; only Open Food Facts provides these.
    var sugarPer100g: Double? = nil
    var saltPer100g: Double? = nil
    var fiberPer100g: Double? = nil

    var displayName: String {
        if let brand, !brand.isEmpty, !name.localizedCaseInsensitiveContains(brand) {
            return "\(name) (\(brand))"
        }
        return name
    }

    /// Largest portion any source may claim. Guards the Int conversions below:
    /// nutrition values are already clamped per 100 g, but an unbounded serving
    /// size (a malformed Open Food Facts serving_quantity, or a very long number
    /// typed into the custom-food form) would otherwise reach Int() as a
    /// non-finite or out-of-range Double and crash.
    static let maxServingGrams: Double = 10_000

    /// A grams amount safe to multiply and cast to Int.
    private func safeGrams(_ grams: Double) -> Double {
        guard grams.isFinite, grams > 0 else { return 0 }
        return min(grams, Self.maxServingGrams)
    }

    func kcal(for grams: Double) -> Int {
        Int((kcalPer100g * safeGrams(grams) / 100).rounded())
    }

    func protein(for grams: Double) -> Double { proteinPer100g * safeGrams(grams) / 100 }
    func carbs(for grams: Double) -> Double { carbsPer100g * safeGrams(grams) / 100 }
    func fat(for grams: Double) -> Double { fatPer100g * safeGrams(grams) / 100 }
    func sugar(for grams: Double) -> Double? { sugarPer100g.map { $0 * safeGrams(grams) / 100 } }
    func salt(for grams: Double) -> Double? { saltPer100g.map { $0 * safeGrams(grams) / 100 } }
    func fiber(for grams: Double) -> Double? { fiberPer100g.map { $0 * safeGrams(grams) / 100 } }
}
