import Foundation

/// A healthy Swiss recipe from the bundled collection; nutrition per serving.
struct Recipe: Codable, Identifiable, Hashable {
    enum Category: String, Codable, CaseIterable, Identifiable {
        case breakfast
        case main
        case soup
        case sweet

        var id: String { rawValue }

        var label: String {
            switch self {
            case .breakfast: return "Frühstück".loc
            case .main: return "Hauptgericht".loc
            case .soup: return "Suppe".loc
            case .sweet: return "Süsses".loc
            }
        }
    }

    let id: String
    let name: String
    let category: Category
    let minutes: Int
    let servings: Int
    let gramsPerServing: Double
    let kcal: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let vegetarian: Bool
    let symbol: String
    let ingredients: [String]
    let steps: [String]

    /// Bridges into the existing portion sheet so recipes log like products.
    var asProduct: FoodProduct {
        let factor = 100 / max(1, gramsPerServing)
        return FoodProduct(id: "recipe-\(id)", name: name, brand: nil,
                           kcalPer100g: Double(kcal) * factor,
                           proteinPer100g: proteinG * factor,
                           carbsPer100g: carbsG * factor,
                           fatPer100g: fatG * factor,
                           barcode: nil, source: .swissDatabase,
                           servingGrams: gramsPerServing)
    }
}

enum RecipeStore {
    static let all: [Recipe] = {
        guard let url = Bundle.main.url(forResource: "recipes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let recipes = try? JSONDecoder().decode([Recipe].self, from: data) else { return [] }
        return recipes
    }()
}
