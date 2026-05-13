// PantryStaplesService.swift
// ChefNova
//
// Provides the cuisine-specific list of pantry staples — basic spices and
// condiments the app treats as implicitly available in the user's kitchen.
// Data is loaded once from the bundled `PantryStaples.json` file.

import Foundation

// MARK: - Protocol

/// Defines the interface for pantry staples lookup.
protocol PantryStaplesServiceProtocol {
    /// Returns the list of pantry staple ingredient names for the given cuisine.
    ///
    /// The returned names are in their canonical form (e.g. "Cumin Seeds").
    func getPantryStaples(for cuisine: Cuisine) -> [String]

    /// Returns `true` if `ingredient` is a pantry staple for the given cuisine.
    ///
    /// Comparison is case-insensitive so callers do not need to normalise the
    /// ingredient name before calling this method.
    func isPantryStaple(_ ingredient: String, for cuisine: Cuisine) -> Bool
}

// MARK: - Implementation

/// Loads `PantryStaples.json` from the app bundle once at initialisation and
/// answers pantry staple queries entirely on-device with case-insensitive
/// comparisons.
///
/// `PantryStaples.json` is a JSON object whose keys are cuisine raw values
/// (e.g. `"North Indian"`) and whose values are arrays of canonical ingredient
/// name strings.
///
/// ```json
/// {
///   "North Indian": ["Salt", "Black Pepper", "Turmeric", ...]
/// }
/// ```
final class PantryStaplesService: PantryStaplesServiceProtocol {

    // MARK: Private state

    /// Staples keyed by cuisine raw value, with each list stored as a
    /// `Set<String>` of lowercased names for O(1) membership tests.
    private let staplesByCuisine: [String: [String]]

    /// Lowercased sets for fast `isPantryStaple` lookups.
    private let staplesSetByCuisine: [String: Set<String>]

    // MARK: Init

    /// Creates the service by loading and decoding `PantryStaples.json`
    /// from `bundle`.
    ///
    /// - Parameter bundle: The bundle to search for the JSON file.
    ///   Defaults to `Bundle.main`; override in tests to supply a fixture.
    init(bundle: Bundle = .main) {
        guard
            let url = bundle.url(forResource: "PantryStaples", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let raw = try? JSONDecoder().decode([String: [String]].self, from: data)
        else {
            // Fail loudly in debug builds so a missing/malformed JSON file is
            // caught immediately; fall back to empty maps in production.
            assertionFailure("PantryStaplesService: failed to load PantryStaples.json")
            staplesByCuisine = [:]
            staplesSetByCuisine = [:]
            return
        }

        staplesByCuisine = raw

        // Pre-build lowercased sets for O(1) case-insensitive membership tests.
        var sets: [String: Set<String>] = [:]
        sets.reserveCapacity(raw.count)
        for (cuisine, staples) in raw {
            sets[cuisine] = Set(staples.map { $0.lowercased() })
        }
        staplesSetByCuisine = sets
    }

    // MARK: PantryStaplesServiceProtocol

    func getPantryStaples(for cuisine: Cuisine) -> [String] {
        staplesByCuisine[cuisine.rawValue] ?? []
    }

    func isPantryStaple(_ ingredient: String, for cuisine: Cuisine) -> Bool {
        let lowercased = ingredient.lowercased()
        return staplesSetByCuisine[cuisine.rawValue]?.contains(lowercased) ?? false
    }
}
