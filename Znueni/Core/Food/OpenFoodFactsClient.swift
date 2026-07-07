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

    /// Returns nil when the barcode is unknown to Open Food Facts.
    static func fetchProduct(barcode: String) async throws -> FoodProduct? {
        let digits = barcode.filter(\.isNumber)
        guard (6...14).contains(digits.count) else { throw LookupError.invalidBarcode }

        let fields = "product_name,product_name_de,brands,nutriments,serving_quantity"
        guard let url = URL(string: "https://ch.openfoodfacts.org/api/v2/product/\(digits)?fields=\(fields)") else {
            throw LookupError.invalidBarcode
        }

        var request = URLRequest(url: url)
        request.setValue("Znueni iOS/0.1 (personal use)", forHTTPHeaderField: "User-Agent")

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: request)
        } catch {
            throw LookupError.network
        }

        guard let response = try? JSONDecoder().decode(OFFResponse.self, from: data),
              response.status == 1,
              let product = response.product else {
            return nil
        }

        let name = [product.productNameDe, product.productName]
            .compactMap { $0 }
            .first { !$0.isEmpty } ?? "Unbekanntes Produkt"

        let nutriments = product.nutriments
        let kcal = nutriments?.energyKcal100g
            ?? nutriments.flatMap { $0.energyKj100g.map { kj in kj / 4.184 } }
            ?? 0

        return FoodProduct(
            id: "off-\(digits)",
            name: name,
            brand: product.brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces),
            kcalPer100g: kcal,
            proteinPer100g: nutriments?.proteins100g ?? 0,
            carbsPer100g: nutriments?.carbohydrates100g ?? 0,
            fatPer100g: nutriments?.fat100g ?? 0,
            barcode: digits,
            source: .openFoodFacts,
            servingGrams: product.servingQuantity.flatMap { $0 > 0 ? $0 : nil })
    }

    // MARK: - Response types

    private struct OFFResponse: Decodable {
        let status: Int
        let product: OFFProduct?
    }

    private struct OFFProduct: Decodable {
        let productName: String?
        let productNameDe: String?
        let brands: String?
        let nutriments: OFFNutriments?
        let servingQuantity: Double?

        enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case productNameDe = "product_name_de"
            case brands
            case nutriments
            case servingQuantity = "serving_quantity"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            productName = try? container.decode(String.self, forKey: .productName)
            productNameDe = try? container.decode(String.self, forKey: .productNameDe)
            brands = try? container.decode(String.self, forKey: .brands)
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
        let proteins100g: Double?
        let carbohydrates100g: Double?
        let fat100g: Double?

        enum CodingKeys: String, CodingKey {
            case energyKcal100g = "energy-kcal_100g"
            case energyKj100g = "energy_100g"
            case proteins100g = "proteins_100g"
            case carbohydrates100g = "carbohydrates_100g"
            case fat100g = "fat_100g"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            energyKcal100g = Self.flexibleDouble(container, .energyKcal100g)
            energyKj100g = Self.flexibleDouble(container, .energyKj100g)
            proteins100g = Self.flexibleDouble(container, .proteins100g)
            carbohydrates100g = Self.flexibleDouble(container, .carbohydrates100g)
            fat100g = Self.flexibleDouble(container, .fat100g)
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
