import UIKit

/// Some downloaded simulator runtimes ship without a working color emoji font;
/// views fall back to SF Symbols there. Real devices always have it.
/// Font-table checks lie on those runtimes, so this draws an emoji into a tiny
/// bitmap and looks for colored pixels (the missing-glyph box is monochrome).
enum EmojiSupport {
    static let available: Bool = {
        let side = 12
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let ctx = CGContext(data: &pixels, width: side, height: side,
                                  bitsPerComponent: 8, bytesPerRow: side * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        UIGraphicsPushContext(ctx)
        ("🍳" as NSString).draw(in: CGRect(x: 0, y: 0, width: side, height: side),
                                withAttributes: [.font: UIFont.systemFont(ofSize: CGFloat(side) - 2)])
        UIGraphicsPopContext()
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
            if max(r, g, b) - min(r, g, b) > 16 { return true }
        }
        return false
    }()
}

/// A healthy recipe from the bundled collection; nutrition per serving.
struct Recipe: Codable, Identifiable, Hashable {
    enum Category: String, Codable, CaseIterable, Identifiable {
        case breakfast
        case main
        case soup
        case salad
        case snack
        case sweet

        var id: String { rawValue }

        var label: String {
            switch self {
            case .breakfast: return "Frühstück".loc
            case .main: return "Hauptgericht".loc
            case .soup: return "Suppe".loc
            case .salad: return "Salat".loc
            case .snack: return "Snack".loc
            case .sweet: return "Süsses".loc
            }
        }

        var emoji: String {
            switch self {
            case .breakfast: return "🍳"
            case .main: return "🍲"
            case .soup: return "🥣"
            case .salad: return "🥗"
            case .snack: return "🥨"
            case .sweet: return "🍓"
            }
        }

        /// SF Symbol stand-in for runtimes without the emoji font.
        var symbol: String {
            switch self {
            case .breakfast: return "cup.and.saucer.fill"
            case .main: return "fork.knife"
            case .soup: return "mug.fill"
            case .salad: return "leaf.fill"
            case .snack: return "takeoutbag.and.cup.and.straw.fill"
            case .sweet: return "birthday.cake.fill"
            }
        }
    }

    enum Cuisine: String, Codable, CaseIterable, Identifiable {
        case italian
        case balkan
        case greek
        case turkish
        case levante
        case french
        case spanish
        case mexican
        case latin
        case american
        case indian
        case thai
        case vietnamese
        case chinese
        case japanese
        case korean
        case african

        var id: String { rawValue }

        var label: String {
            switch self {
            case .italian: return "Italienisch".loc
            case .balkan: return "Balkan".loc
            case .greek: return "Griechisch".loc
            case .turkish: return "Türkisch".loc
            case .levante: return "Orientalisch".loc
            case .french: return "Französisch".loc
            case .spanish: return "Spanisch".loc
            case .mexican: return "Mexikanisch".loc
            case .latin: return "Lateinamerikanisch".loc
            case .american: return "Amerikanisch".loc
            case .indian: return "Indisch".loc
            case .thai: return "Thailändisch".loc
            case .vietnamese: return "Vietnamesisch".loc
            case .chinese: return "Chinesisch".loc
            case .japanese: return "Japanisch".loc
            case .korean: return "Koreanisch".loc
            case .african: return "Afrikanisch".loc
            }
        }

        var emoji: String {
            switch self {
            case .italian: return "🇮🇹"
            case .balkan: return "🫓"
            case .greek: return "🇬🇷"
            case .turkish: return "🇹🇷"
            case .levante: return "🧆"
            case .french: return "🇫🇷"
            case .spanish: return "🇪🇸"
            case .mexican: return "🇲🇽"
            case .latin: return "🫔"
            case .american: return "🇺🇸"
            case .indian: return "🇮🇳"
            case .thai: return "🇹🇭"
            case .vietnamese: return "🇻🇳"
            case .chinese: return "🇨🇳"
            case .japanese: return "🇯🇵"
            case .korean: return "🇰🇷"
            case .african: return "🥘"
            }
        }

        /// SF Symbol stand-in for runtimes without the emoji font.
        var symbol: String {
            switch self {
            case .italian, .balkan, .greek, .turkish, .french, .spanish:
                return "globe.europe.africa.fill"
            case .levante, .indian:
                return "globe.central.south.asia.fill"
            case .mexican, .latin, .american:
                return "globe.americas.fill"
            case .thai, .vietnamese, .chinese, .japanese, .korean:
                return "globe.asia.australia.fill"
            case .african:
                return "globe.europe.africa"
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
    let vegan: Bool
    let swiss: Bool
    /// World cuisine of the dish; nil for the original Swiss and everyday collection.
    let cuisine: Cuisine?
    let emoji: String
    let ingredients: [String]
    let steps: [String]

    var isHighProtein: Bool { proteinG >= 25 }
    var isLowCarb: Bool { carbsG <= 20 }

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

extension Recipe {
    /// Bundled photo; community submissions land here as recipe-<id>.jpg.
    var photo: UIImage? {
        UIImage(named: "recipe-\(id).jpg")
    }

    /// This recipe's page on the website, where a photo can be submitted.
    var photoSubmitURL: URL {
        let slug = id.replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        return URL(string: "https://zwaeg.app/rezepte/\(slug)/")
            ?? URL(string: "https://zwaeg.app/rezepte/")!
    }
}

/// Attribution for a bundled recipe photo; see docs/IMAGE-CREDITS.md.
struct RecipeCredit: Codable {
    let id: String
    let title: String
    let artist: String
    let license: String
    let source: String
}

enum RecipeCredits {
    static let byId: [String: RecipeCredit] = {
        guard let url = Bundle.main.url(forResource: "credits", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let credits = try? JSONDecoder().decode([RecipeCredit].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: credits.map { ($0.id, $0) })
    }()
}

enum RecipeStore {
    private static let files = ["recipes-breakfast", "recipes-soups", "recipes-salads",
                                "recipes-mains-1", "recipes-mains-2", "recipes-snacks",
                                "recipes-sweets"]
        + Recipe.Cuisine.allCases.map { "recipes-intl-\($0.rawValue)" }

    static let all: [Recipe] = files.flatMap { file -> [Recipe] in
        guard let url = Bundle.main.url(forResource: file, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let recipes = try? JSONDecoder().decode([Recipe].self, from: data) else { return [] }
        return recipes
    }
}

/// Persisted set of favorite recipe ids.
@Observable
final class RecipeFavorites {
    static let shared = RecipeFavorites()

    private static let key = "favoriteRecipes"

    private(set) var ids: Set<String>

    init() {
        ids = Set(UserDefaults.standard.stringArray(forKey: Self.key) ?? [])
    }

    func contains(_ id: String) -> Bool {
        ids.contains(id)
    }

    func toggle(_ id: String) {
        if !ids.insert(id).inserted {
            ids.remove(id)
        }
        UserDefaults.standard.set(Array(ids).sorted(), forKey: Self.key)
    }
}
