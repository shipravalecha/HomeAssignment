// BarcodeProductLookupService.swift
// ChefNova
//
// Resolves a scanned barcode (UPC/EAN) to a product name using the
// Open Food Facts API — no API key required.
//
// API docs: https://world.openfoodfacts.org/data

import Foundation

// MARK: - Protocol

protocol BarcodeProductLookupServiceProtocol: Sendable {
    /// Looks up a barcode and returns the best candidate ingredient name,
    /// or `nil` if the product is not found or the response is unusable.
    func lookupIngredientName(for barcode: String) async -> String?
}

// MARK: - Open Food Facts response models (private)

private struct OFFResponse: Decodable {
    let status: Int          // 1 = found, 0 = not found
    let product: OFFProduct?
}

private struct OFFProduct: Decodable {
    /// Short product name, e.g. "Amul Fresh Paneer"
    let productName: String?
    /// Generic name, e.g. "Paneer"
    let genericName: String?
    /// Main category tag, e.g. "en:paneer"
    let mainCategory: String?

    enum CodingKeys: String, CodingKey {
        case productName  = "product_name"
        case genericName  = "generic_name"
        case mainCategory = "main_category"
    }
}

// MARK: - Implementation

/// Calls the Open Food Facts API to resolve a barcode to an ingredient name.
///
/// Resolution priority:
///   1. `generic_name` — most likely to match a canonical ingredient
///   2. `product_name` — full product name (may include brand/weight)
///   3. `main_category` — last resort, strips the language prefix (e.g. "en:paneer" → "paneer")
final class BarcodeProductLookupService: BarcodeProductLookupServiceProtocol {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func lookupIngredientName(for barcode: String) async -> String? {
        // Sanitise: barcodes are numeric strings
        let sanitised = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitised.isEmpty,
              sanitised.allSatisfy({ $0.isNumber }) else { return nil }

        let urlString = "https://world.openfoodfacts.org/api/v0/product/\(sanitised).json"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200 else { return nil }

            let decoded = try JSONDecoder().decode(OFFResponse.self, from: data)
            guard decoded.status == 1, let product = decoded.product else { return nil }

            return bestName(from: product)
        } catch {
            return nil
        }
    }

    // MARK: - Private helpers

    /// Picks the most useful name from the product record.
    private func bestName(from product: OFFProduct) -> String? {
        // 1. Generic name is cleanest (e.g. "Paneer", "Chickpeas")
        if let name = product.genericName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        // 2. Product name (may include brand/weight — caller will normalise)
        if let name = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        // 3. Strip language prefix from category tag: "en:paneer" → "Paneer"
        if let category = product.mainCategory {
            let stripped = category
                .components(separatedBy: ":")
                .last?
                .replacingOccurrences(of: "-", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .capitalized
            if let stripped, !stripped.isEmpty {
                return stripped
            }
        }
        return nil
    }
}
