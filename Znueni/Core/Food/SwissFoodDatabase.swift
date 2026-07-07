import Foundation

/// Offline search over the bundled list of common Swiss and generic foods.
/// Values are per 100 g, curated from public nutrition data. A full import
/// of the Swiss food composition database can replace this later.
final class SwissFoodDatabase {
    static let shared = SwissFoodDatabase()

    private(set) var foods: [FoodProduct] = []

    private init() {
        guard let url = Bundle.main.url(forResource: "swiss_foods", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            assertionFailure("swiss_foods.json missing or invalid")
            return
        }
        foods = entries.map { entry in
            FoodProduct(
                id: "ch-\(entry.name)",
                name: entry.name,
                brand: nil,
                kcalPer100g: entry.kcal,
                proteinPer100g: entry.protein,
                carbsPer100g: entry.carbs,
                fatPer100g: entry.fat,
                barcode: nil,
                source: .swissDatabase)
        }
    }

    func search(_ query: String) -> [FoodProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }
        return foods
            .filter { $0.name.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
            .sorted { lhs, rhs in
                let lhsPrefix = lhs.name.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) != nil
                let rhsPrefix = rhs.name.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) != nil
                if lhsPrefix != rhsPrefix { return lhsPrefix }
                return lhs.name < rhs.name
            }
    }

    private struct Entry: Decodable {
        let name: String
        let kcal: Double
        let protein: Double
        let carbs: Double
        let fat: Double
    }
}
