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

    var displayName: String {
        if let brand, !brand.isEmpty, !name.localizedCaseInsensitiveContains(brand) {
            return "\(name) (\(brand))"
        }
        return name
    }

    func kcal(for grams: Double) -> Int {
        Int((kcalPer100g * grams / 100).rounded())
    }

    func protein(for grams: Double) -> Double { proteinPer100g * grams / 100 }
    func carbs(for grams: Double) -> Double { carbsPer100g * grams / 100 }
    func fat(for grams: Double) -> Double { fatPer100g * grams / 100 }
}
