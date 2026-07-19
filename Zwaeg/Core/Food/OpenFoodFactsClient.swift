import Foundation

/// Barcode lookup against the Open Food Facts database (Swiss instance).
enum OpenFoodFactsClient {

    enum LookupError: LocalizedError {
        case invalidBarcode
        case network

        var errorDescription: String? {
            switch self {
            case .invalidBarcode: return "Ungültiger Barcode"
            case .network: return "Keine Verbindung. Bitte später erneut versuchen."
            }
        }
    }

    /// Open Food Facts language for the app language; dialects map to their
    /// written base so Swiss German users search the German product names.
    static var languageCode: String {
        switch Lingo.shared.language.rawValue {
        case "gsw", "rm": return "de"
        case "nb": return "no"
        case let code: return code
        }
    }

    private static var fields: String {
        "product_name,product_name_\(languageCode),brands,nutriments,serving_quantity"
    }

    private static func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        // Open Food Facts asks API users to identify themselves with a
        // descriptive User-Agent including a contact point.
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        request.setValue("Zwaeg iOS/\(version) (https://zwaeg.app)", forHTTPHeaderField: "User-Agent")
        return request
    }

    /// Returns nil when the barcode is unknown to Open Food Facts.
    static func fetchProduct(barcode: String) async throws -> FoodProduct? {
        let digits = barcode.filter(\.isNumber)
        guard (6...14).contains(digits.count) else { throw LookupError.invalidBarcode }

        guard let url = URL(string: "https://ch.openfoodfacts.org/api/v2/product/\(digits)?fields=\(fields)") else {
            throw LookupError.invalidBarcode
        }

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: request(for: url))
        } catch {
            throw LookupError.network
        }

        guard let response = try? JSONDecoder().decode(OFFResponse.self, from: data),
              response.status == 1,
              let product = response.product else {
            return nil
        }
        return foodProduct(from: product, digits: digits)
    }

    /// Free-text name search via Search-a-licious (the classic search.pl is
    /// gone), for products the offline database doesn't carry ("Kaffee
    /// Latte"). Searches in the app language plus English. Best-effort:
    /// empty on any error. Entries whose nutrition table was never filled in
    /// are dropped — but an explicit zero stays, or Cola Zero would vanish.
    static func searchProducts(name: String, limit: Int = 24) async -> [FoodProduct] {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let langs = languageCode == "en" ? "en" : "\(languageCode),en"
        guard trimmed.count >= 3,
              let escaped = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://search.openfoodfacts.org/search?q=\(escaped)"
                            + "&page_size=\(limit)&langs=\(langs)&fields=code,\(fields)") else {
            return []
        }
        guard let (data, _) = try? await URLSession.shared.data(for: request(for: url)),
              let response = try? JSONDecoder().decode(OFFSearchResponse.self, from: data) else {
            return []
        }
        return response.hits.compactMap { product in
            guard let digits = product.code?.filter(\.isNumber), (6...14).contains(digits.count),
                  product.nutriments?.hasExplicitEnergy == true else {
                return nil
            }
            return foodProduct(from: product, digits: digits)
        }
    }

    private static func foodProduct(from product: OFFProduct, digits: String) -> FoodProduct {
        let name = [product.productNameLocalized, product.productName]
            .compactMap { $0 }
            .first { !$0.isEmpty } ?? "Unbekanntes Produkt"

        let nutriments = product.nutriments
        let kcal = nutriments?.energyKcal100g
            ?? nutriments.flatMap { $0.energyKj100g.map { kj in kj / 4.184 } }
            ?? 0

        // Crowd-sourced values get clamped to physically plausible ranges.
        func clamped(_ value: Double?, max maxValue: Double) -> Double {
            min(maxValue, Swift.max(0, value ?? 0))
        }

        return FoodProduct(
            id: "off-\(digits)",
            name: String(name.prefix(120)),
            brand: product.brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces),
            kcalPer100g: clamped(kcal, max: 900),
            proteinPer100g: clamped(nutriments?.proteins100g, max: 100),
            carbsPer100g: clamped(nutriments?.carbohydrates100g, max: 100),
            fatPer100g: clamped(nutriments?.fat100g, max: 100),
            barcode: digits,
            source: .openFoodFacts,
            servingGrams: product.servingQuantity.flatMap {
                $0.isFinite && $0 > 0 ? min($0, FoodProduct.maxServingGrams) : nil
            },
            sugarPer100g: nutriments?.sugars100g.map { min(100, Swift.max(0, $0)) },
            saltPer100g: nutriments?.salt100g.map { min(100, Swift.max(0, $0)) },
            fiberPer100g: nutriments?.fiber100g.map { min(100, Swift.max(0, $0)) })
    }

    // MARK: - Response types

    private struct OFFResponse: Decodable {
        let status: Int
        let product: OFFProduct?
    }

    private struct OFFSearchResponse: Decodable {
        let hits: [OFFProduct]
    }

    /// String-addressed key for fields whose name depends on the app
    /// language (product_name_<lang>).
    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }

        init(_ string: String) { stringValue = string }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    private struct OFFProduct: Decodable {
        let code: String?
        let productName: String?
        let productNameLocalized: String?
        let brands: String?
        let nutriments: OFFNutriments?
        let servingQuantity: Double?

        enum CodingKeys: String, CodingKey {
            case code
            case productName = "product_name"
            case brands
            case nutriments
            case servingQuantity = "serving_quantity"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // The barcode arrives as string or number depending on endpoint.
            if let text = try? container.decode(String.self, forKey: .code) {
                code = text
            } else if let value = try? container.decode(Int.self, forKey: .code) {
                code = String(value)
            } else {
                code = nil
            }
            productName = try? container.decode(String.self, forKey: .productName)
            let localized = try? decoder.container(keyedBy: AnyKey.self)
                .decode(String.self, forKey: AnyKey("product_name_\(OpenFoodFactsClient.languageCode)"))
            productNameLocalized = localized
            // Comma string on the product endpoint, array on the search API.
            if let text = try? container.decode(String.self, forKey: .brands) {
                brands = text
            } else if let list = try? container.decode([String].self, forKey: .brands) {
                brands = list.joined(separator: ",")
            } else {
                brands = nil
            }
            nutriments = try? container.decode(OFFNutriments.self, forKey: .nutriments)
            if let value = try? container.decode(Double.self, forKey: .servingQuantity) {
                servingQuantity = value
            } else if let text = try? container.decode(String.self, forKey: .servingQuantity) {
                servingQuantity = Double(text)
            } else {
                servingQuantity = nil
            }
        }
    }

    private struct OFFNutriments: Decodable {
        let energyKcal100g: Double?
        let energyKj100g: Double?

        /// The table was actually filled in; an explicit 0 counts (diet
        /// drinks), a missing field does not.
        var hasExplicitEnergy: Bool {
            energyKcal100g != nil || energyKj100g != nil
        }
        let proteins100g: Double?
        let carbohydrates100g: Double?
        let fat100g: Double?
        let sugars100g: Double?
        let salt100g: Double?
        let fiber100g: Double?

        enum CodingKeys: String, CodingKey {
            case energyKcal100g = "energy-kcal_100g"
            case energyKj100g = "energy_100g"
            case proteins100g = "proteins_100g"
            case carbohydrates100g = "carbohydrates_100g"
            case fat100g = "fat_100g"
            case sugars100g = "sugars_100g"
            case salt100g = "salt_100g"
            case fiber100g = "fiber_100g"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            energyKcal100g = Self.flexibleDouble(container, .energyKcal100g)
            energyKj100g = Self.flexibleDouble(container, .energyKj100g)
            proteins100g = Self.flexibleDouble(container, .proteins100g)
            carbohydrates100g = Self.flexibleDouble(container, .carbohydrates100g)
            fat100g = Self.flexibleDouble(container, .fat100g)
            sugars100g = Self.flexibleDouble(container, .sugars100g)
            salt100g = Self.flexibleDouble(container, .salt100g)
            fiber100g = Self.flexibleDouble(container, .fiber100g)
        }

        /// Open Food Facts sometimes returns numbers as strings.
        private static func flexibleDouble(
            _ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys
        ) -> Double? {
            if let value = try? container.decode(Double.self, forKey: key) { return value }
            if let text = try? container.decode(String.self, forKey: key) { return Double(text) }
            return nil
        }
    }
}
