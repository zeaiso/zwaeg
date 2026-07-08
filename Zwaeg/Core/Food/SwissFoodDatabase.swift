import Foundation

/// Offline search over the official Swiss Food Composition Database
/// (Schweizer Nährwertdatenbank v7.0, BLV, naehrwertdaten.ch).
/// Values are per 100 g edible portion; synonyms are searchable
/// (e.g. "Chlöpfer" finds Cervelat).
final class SwissFoodDatabase {
    static let shared = SwissFoodDatabase()

    private(set) var foods: [FoodProduct] = []
    /// Product id to searchable synonym text ("Bockwurst;Stumpen;Chlöpfer").
    private var synonyms: [String: String] = [:]

    private init() {
        guard let url = Bundle.main.url(forResource: "swiss_foods", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            assertionFailure("swiss_foods.json missing or invalid")
            return
        }
        foods = entries.map { entry in
            let id = "ch-\(entry.name)"
            if let synonymText = entry.synonyms {
                synonyms[id] = synonymText
            }
            return FoodProduct(
                id: id,
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
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return foods
            .filter { product in
                if product.name.range(of: trimmed, options: options) != nil {
                    return true
                }
                if let synonymText = synonyms[product.id],
                   synonymText.range(of: trimmed, options: options) != nil {
                    return true
                }
                return false
            }
            .sorted { lhs, rhs in
                let lhsPrefix = lhs.name.range(of: trimmed, options: options.union(.anchored)) != nil
                let rhsPrefix = rhs.name.range(of: trimmed, options: options.union(.anchored)) != nil
                if lhsPrefix != rhsPrefix { return lhsPrefix }
                if lhs.name.count != rhs.name.count { return lhs.name.count < rhs.name.count }
                return lhs.name < rhs.name
            }
    }

    private struct Entry: Decodable {
        let name: String
        let kcal: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let synonyms: String?
    }
}
