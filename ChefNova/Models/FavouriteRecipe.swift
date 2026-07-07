// FavouriteRecipe.swift
// ChefNova
//
// SwiftData model that persists a saved recipe. The full RankedRecipe is
// encoded to JSON and stored as a Data blob so we don't need to mirror
// every Recipe field as SwiftData columns.

import Foundation
import SwiftData

@Model
final class FavouriteRecipe {

    // MARK: - Stored properties

    /// Stable identifier matching `RankedRecipe.id` — used to check duplicates.
    var recipeID: UUID

    /// The recipe title, stored directly for efficient list queries without decoding.
    var title: String

    /// The cuisine name, stored directly for display in the favourites list.
    var cuisine: String

    /// Total cook time in minutes (prep + cook), stored for display without decoding.
    var totalTimeMinutes: Int

    /// JSON-encoded `RankedRecipe`. Decoded on demand in `rankedRecipe`.
    var recipeData: Data

    /// When the user saved this recipe.
    var savedAt: Date

    // MARK: - Init

    init(rankedRecipe: RankedRecipe) throws {
        self.recipeID = rankedRecipe.id
        self.title = rankedRecipe.recipe.title
        self.cuisine = rankedRecipe.recipe.cuisine.rawValue
        self.totalTimeMinutes = rankedRecipe.recipe.prepTimeMinutes + rankedRecipe.recipe.cookTimeMinutes
        self.recipeData = try JSONEncoder().encode(rankedRecipe)
        self.savedAt = Date()
    }

    // MARK: - Decoding

    /// Decodes and returns the full `RankedRecipe`, or `nil` if the data is corrupt.
    var rankedRecipe: RankedRecipe? {
        try? JSONDecoder().decode(RankedRecipe.self, from: recipeData)
    }
}
