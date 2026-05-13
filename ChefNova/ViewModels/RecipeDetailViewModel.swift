// RecipeDetailViewModel.swift
// ChefNova
//
// ViewModel for the Recipe Detail screen. Manages serving size adjustment
// and exposes scaled ingredient quantities to the view.

import Foundation
import Observation

/// View model for the recipe detail screen.
///
/// Holds the selected `RankedRecipe` and a mutable `targetServings` property.
/// When `targetServings` changes, `adjustedIngredients` automatically reflects
/// the scaled quantities.
@MainActor
@Observable
final class RecipeDetailViewModel {

    // MARK: - State

    let rankedRecipe: RankedRecipe

    /// The number of servings the user wants to cook. Defaults to the recipe's
    /// original serving size.
    var targetServings: Int

    // MARK: - Init

    init(rankedRecipe: RankedRecipe) {
        self.rankedRecipe = rankedRecipe
        self.targetServings = rankedRecipe.recipe.servingSize
    }

    // MARK: - Computed Properties

    /// The recipe's ingredients with quantities scaled to `targetServings`.
    var adjustedIngredients: [RecipeIngredient] {
        let originalServings = rankedRecipe.recipe.servingSize
        return rankedRecipe.recipe.ingredients.map { ingredient in
            let scaled = adjustedQuantity(
                original: ingredient.quantity,
                originalServings: originalServings,
                targetServings: targetServings
            )
            return RecipeIngredient(
                name: ingredient.name,
                quantity: scaled,
                unit: ingredient.unit
            )
        }
    }

    // MARK: - Pure Functions

    /// Scales an ingredient quantity from `originalServings` to `targetServings`.
    ///
    /// - Parameters:
    ///   - original: The quantity for the original serving size.
    ///   - originalServings: The serving size the recipe was written for.
    ///   - targetServings: The desired number of servings.
    /// - Returns: The scaled quantity, or `original` if `originalServings` is zero.
    func adjustedQuantity(
        original: Double,
        originalServings: Int,
        targetServings: Int
    ) -> Double {
        guard originalServings > 0 else { return original }
        return original * (Double(targetServings) / Double(originalServings))
    }
}
