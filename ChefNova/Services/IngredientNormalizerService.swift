// IngredientNormalizerService.swift
// ChefNova
//
// Responsible for mapping raw user-entered ingredient names to canonical
// forms using a bundled synonym dictionary (SynonymDictionary.json).

import Foundation

// MARK: - Protocol

/// Defines the interface for ingredient name normalization.
protocol IngredientNormalizerServiceProtocol {
    /// Returns the canonical form of the ingredient name, or `nil` if unrecognized.
    ///
    /// Lookup is case-insensitive and whitespace-trimmed. A `nil` return value
    /// signals that the input should be treated as unrecognized and the user
    /// should be prompted to revise the entry.
    func normalize(_ rawName: String) -> String?

    /// Returns `true` if the raw name maps to a known canonical ingredient.
    func isRecognized(_ rawName: String) -> Bool
}

// MARK: - Implementation

/// Loads `SynonymDictionary.json` from the app bundle once at initialisation
/// and performs case-insensitive, whitespace-trimmed synonym lookups entirely
/// on-device — no network round-trip required.
final class IngredientNormalizerService: IngredientNormalizerServiceProtocol {

    // MARK: Private state

    /// The synonym map keyed by lowercased, trimmed variant names.
    /// Values are the canonical ingredient names (e.g. "Onion").
    private let synonymMap: [String: String]

    // MARK: Init

    /// Creates the service by loading and decoding `SynonymDictionary.json`
    /// from `Bundle.main`.
    ///
    /// - Parameter bundle: The bundle to search for the JSON file.
    ///   Defaults to `Bundle.main`; override in tests to supply a fixture.
    init(bundle: Bundle = .main) {
        guard
            let url = bundle.url(forResource: "SynonymDictionary", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let raw = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            // Fail loudly in debug builds so missing/malformed JSON is caught
            // immediately; fall back to an empty map in production to avoid a crash.
            assertionFailure("IngredientNormalizerService: failed to load SynonymDictionary.json")
            synonymMap = [:]
            return
        }

        // Normalise all keys to lowercase + trimmed so lookups are
        // case-insensitive and whitespace-tolerant at query time.
        var map: [String: String] = [:]
        map.reserveCapacity(raw.count)
        for (key, value) in raw {
            map[key.lowercased().trimmingCharacters(in: .whitespaces)] = value
        }
        synonymMap = map
    }

    // MARK: IngredientNormalizerServiceProtocol

    func normalize(_ rawName: String) -> String? {
        let key = rawName.lowercased().trimmingCharacters(in: .whitespaces)
        // Reject empty / whitespace-only strings before dictionary lookup.
        guard !key.isEmpty else { return nil }
        return synonymMap[key]
    }

    func isRecognized(_ rawName: String) -> Bool {
        normalize(rawName) != nil
    }
}
