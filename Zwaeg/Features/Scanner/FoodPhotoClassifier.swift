import Foundation
import UIKit
import Vision

/// A food recognized on a photo, resolved to an entry of the Swiss database.
struct FoodPhotoGuess: Identifiable, Hashable {
    let product: FoodProduct
    let confidence: Double

    var id: String { product.id }
}

/// Photo mode: classifies a food photo on device with Apple's built-in image
/// taxonomy (VNClassifyImageRequest) and resolves the English class identifiers
/// to entries of the bundled Swiss database. No model ships with the app and
/// the photo never leaves the device.
enum FoodPhotoClassifier {

    /// Classes below this confidence are noise, not guesses.
    private static let minimumConfidence: Float = 0.15
    /// More than a few chips is indecision, not help.
    private static let maxGuesses = 3

    static func guesses(for image: UIImage) async -> [FoodPhotoGuess] {
        let ranked = await classify(image)
            .sorted { $0.confidence > $1.confidence }
            .map { (identifier: $0.identifier, confidence: $0.confidence) }
        return resolve(ranked)
    }

    /// Identifier/confidence pairs → deduped Swiss database guesses. Split
    /// from the Vision call because the simulator can't run the classifier
    /// (no espresso context); -demo-photo feeds identifiers in directly.
    static func resolve(_ ranked: [(identifier: String, confidence: Float)]) -> [FoodPhotoGuess] {
        var guesses: [FoodPhotoGuess] = []
        var seenProducts = Set<String>()
        for (identifier, confidence) in ranked {
            guard confidence >= minimumConfidence,
                  let query = swissQueries[identifier],
                  let product = SwissFoodDatabase.shared.search(query).first,
                  seenProducts.insert(product.id).inserted else { continue }
            guesses.append(FoodPhotoGuess(product: product, confidence: Double(confidence)))
            if guesses.count == maxGuesses { break }
        }
        return guesses
    }

    private static func classify(_ image: UIImage) async -> [VNClassificationObservation] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return await withCheckedContinuation { continuation in
            // perform() can throw after the completion handler already ran;
            // both paths execute on the same queue, so a flag suffices to
            // keep the continuation from resuming twice.
            var resumed = false
            func finish(_ observations: [VNClassificationObservation]) {
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: observations)
            }
            let request = VNClassifyImageRequest { request, _ in
                finish(request.results as? [VNClassificationObservation] ?? [])
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
                do {
                    try handler.perform([request])
                } catch {
                    finish([])
                }
            }
        }
    }

    /// Vision taxonomy identifier → query that lands the sensible product in
    /// SwissFoodDatabase. Queries are (near) exact names because short words
    /// often rank derived products first: "Apfel" would find "Apfelsaft".
    /// Generic parents of the taxonomy (food, fruit, vegetable, dessert, ...)
    /// are deliberately absent — a guess the portion sheet can't price is
    /// worse than no guess.
    private static let swissQueries: [String: String] = [
        // Fruits
        "apple": "Apfel, roh",
        "apricot": "Aprikose, roh",
        "avocado": "Avocado, roh",
        "banana": "Banane, roh",
        "blackberry": "Brombeere, roh",
        "blueberry": "Heidelbeere, roh",
        "cherry": "Kirsche, roh",
        "coconut": "Kokosnuss",
        "fig": "Feige, roh",
        "grape": "Traube, weiss, roh",
        "grapefruit": "Grapefruit (weiss oder rot), roh",
        "honeydew": "Zuckermelone (Honigmelone), roh",
        "kiwi": "Kiwi, roh",
        "lemon": "Zitrone, roh",
        "mango": "Mango, roh",
        "melon": "Wassermelone, roh",
        "oranges": "Orange, roh",
        "peach": "Pfirsich, gelb, roh",
        "pear": "Birne, roh",
        "pineapple": "Ananas, roh",
        "plum": "Pflaume, roh",
        "raspberry": "Himbeere, roh",
        "strawberry": "Erdbeere, roh",
        "watermelon": "Wassermelone, roh",
        // Vegetables
        "artichoke": "Artischocken, Herz, abgetropft (Konserve)",
        "asparagus": "Spargel, grün, roh",
        "beet": "Rande, roh",
        "bell_pepper": "Peperoni, rot, roh",
        "pepper_veggie": "Peperoni, rot, roh",
        "broccoli": "Broccoli, roh",
        "carrot": "Karotte, roh",
        "cauliflower": "Blumenkohl, roh",
        "corn": "Mais, roh",
        "cucumber": "Gurke, roh",
        "eggplant": "Aubergine, roh",
        "garlic": "Knoblauch, roh",
        "leek": "Lauch, roh",
        "lettuce": "Kopfsalat, roh",
        "salad": "Blattsalat (Durchschnitt), roh",
        "mushroom": "Champignon, roh",
        "onion": "Zwiebel, roh",
        "potato": "Kartoffel, geschält, roh",
        "pumpkin": "Kürbis, roh",
        "radish": "Radieschen, roh",
        "spinach": "Spinat, roh",
        "tomato": "Tomate, roh",
        "zucchini": "Zucchetti, roh",
        // Staples and prepared dishes
        "bread": "Brot (Durchschnitt)",
        "white_bread": "Weissbrot",
        "croissant": "Gipfeli (Durchschnitt)",
        "cereal": "Müeslimischung, Getreideflocken mit Früchten und Nüssen, ungesüsst",
        "oatmeal": "Haferflocken",
        "cheese": "Emmentaler, vollfett",
        "egg": "Hühnerei, ganz, roh",
        "fried_egg": "Hühnerei, ganz, festgekocht",
        "scrambled_eggs": "Rührei mit Kräutern, zubereitet",
        "fish": "Fisch (Durchschnitt), roh",
        "salmon": "Lachs, Zucht, roh",
        "fried_chicken": "Poulet, Brust, mit Haut, roh",
        "grilled_chicken": "Poulet, Brust, Schnitzel oder Geschnetzeltes, gebraten (ohne Zusatz von Fett und Salz)",
        "steak": "Rind, Entrecôte, \"medium\" gebraten (ohne Zusatz von Fett und Salz)",
        "sausage": "Cervelat",
        "hamburger": "Hamburger, doppelt",
        "fries": "Pommes Frites (im Ofen gebacken), ungesalzen",
        "sandwich": "Sandwich (Ruchbrot) mit Salami",
        "pizza": "Pizza Margherita, gebacken",
        "pasta": "Teigwaren ohne Ei, gekocht im Salzwasser (unjodiert)",
        "spaghetti": "Teigwaren ohne Ei, gekocht im Salzwasser (unjodiert)",
        "rice": "Reis poliert, gekocht in Salzwasser (unjodiert)",
        // Sweets and snacks
        "birthday_cake": "Schokoladenkuchen, feucht, hausgemacht",
        "cake_regular": "Schokoladenkuchen, feucht, hausgemacht",
        "wedding_cake": "Schokoladenkuchen, feucht, hausgemacht",
        "cheesecake": "Käsekuchen, gebacken (mit Kuchenteig)",
        "cupcake": "Schokoladencake/ -gugelhopf/ -muffin, hausgemacht",
        "chocolate": "Milchschokolade",
        "donut": "Donut mit Schokoladen-Glasur",
        "gingerbread": "Lebkuchen",
        "ice_cream": "Rahmglace, Aroma",
        "frozen_dessert": "Rahmglace, Aroma",
        "waffle": "Waffel, frisch",
        "honey": "Honig (Blütenhonig)",
        "popcorn": "Popcorn",
        // Nuts, drinks, dairy
        "almond": "Mandel",
        "peanut": "Erdnuss",
        "coffee": "Kaffee, schwarz, ungezuckert",
        "juice": "Orangensaft",
        "yogurt": "Joghurt, nature",
    ]
}
