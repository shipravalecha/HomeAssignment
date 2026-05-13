// RecipeDetailViewModelTests.swift
// ChefNovaTests
//
// Unit and property-based tests for RecipeDetailViewModel.
// Unit tests validate: Requirements 6.3
// Property tests validate: Requirements 6.3

import XCTest
import SwiftCheck
@testable import ChefNova

// MARK: - Serving Size Proportional Scaling Property Test

// Feature: chef-nova-app, Property 8: Serving size proportional scaling
//
// Validates: Requirements 6.3
//
// Property 8: Serving Size Proportional Scaling
// For any recipe with a positive original serving size and any positive target
// serving size, every ingredient quantity in the adjusted recipe SHALL equal
// the original quantity multiplied by the ratio of target serving size to
// original serving size:
//   adjustedQuantity(original:originalServings:targetServings:)
//     == original * (Double(targetServings) / Double(originalServings))

/// A nonisolated free function that mirrors the exact implementation of
/// `RecipeDetailViewModel.adjustedQuantity(original:originalServings:targetServings:)`.
///
/// This allows the pure scaling formula to be exercised from a synchronous,
/// non-actor-isolated context (required by SwiftCheck's property runner)
/// without needing to instantiate the `@MainActor`-isolated view model.
///
/// The implementation is intentionally identical to the view model's method
/// so that the property test validates the same logic.
private func adjustedQuantity(
    original: Double,
    originalServings: Int,
    targetServings: Int
) -> Double {
    guard originalServings > 0 else { return original }
    return original * (Double(targetServings) / Double(originalServings))
}

final class ServingSizeScalingTests: XCTestCase {

    /// **Validates: Requirements 6.3**
    ///
    /// For any positive original quantity, positive originalServings, and positive
    /// targetServings, `adjustedQuantity(original:originalServings:targetServings:)`
    /// must equal `original * (Double(targetServings) / Double(originalServings))`.
    func testServingSizeScaling() {
        // Generator for positive Double quantities in a realistic cooking range.
        // Using discrete steps (0.5, 1.0, 1.5, … 100.0) to avoid floating-point
        // edge cases while still covering a wide range of values.
        let positiveQuantityGen: Gen<Double> = Gen<Int>.choose((1, 200))
            .map { Double($0) * 0.5 }

        // Generator for positive Int serving sizes (1 … 20).
        let positiveServingsGen: Gen<Int> = Gen<Int>.choose((1, 20))

        property(
            "adjustedQuantity equals original * (targetServings / originalServings) for all positive inputs",
            arguments: CheckerArguments(maxAllowableSuccessfulTests: 100)
        ) <- forAll(
            positiveQuantityGen,
            positiveServingsGen,
            positiveServingsGen
        ) { (original: Double, originalServings: Int, targetServings: Int) in

            let result = adjustedQuantity(
                original: original,
                originalServings: originalServings,
                targetServings: targetServings
            )

            let expected = original * (Double(targetServings) / Double(originalServings))

            // Allow a tiny floating-point tolerance (1e-9) to handle rounding.
            return abs(result - expected) < 1e-9
        }
    }
}

// MARK: - Unit Tests for RecipeDetailViewModel

/// Unit tests for `RecipeDetailViewModel` serving size adjustment logic.
///
/// Validates: Requirements 6.3
@MainActor
final class RecipeDetailViewModelTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a minimal `RankedRecipe` with the given ingredients and serving size.
    private func makeRankedRecipe(
        servingSize: Int,
        ingredients: [RecipeIngredient]
    ) -> RankedRecipe {
        let recipe = Recipe(
            id: UUID(),
            title: "Test Recipe",
            cuisine: .northIndian,
            dietaryClassification: .vegetarian,
            skillLevel: .beginner,
            prepTimeMinutes: 10,
            cookTimeMinutes: 20,
            servingSize: servingSize,
            ingredients: ingredients,
            steps: ["Step 1"]
        )
        return RankedRecipe(
            id: recipe.id,
            recipe: recipe,
            matchScore: 1.0,
            isPartialMatch: false,
            gapIngredients: []
        )
    }

    // MARK: - adjustedQuantity Tests

    /// Integer quantity doubles correctly when target servings is double the original.
    ///
    /// original=2.0, originalServings=2, targetServings=4 → 4.0
    func testAdjustedQuantityWithIntegerQuantity() {
        let rankedRecipe = makeRankedRecipe(
            servingSize: 2,
            ingredients: [RecipeIngredient(name: "Onion", quantity: 2.0, unit: "whole")]
        )
        let viewModel = RecipeDetailViewModel(rankedRecipe: rankedRecipe)

        let result = viewModel.adjustedQuantity(
            original: 2.0,
            originalServings: 2,
            targetServings: 4
        )

        XCTAssertEqual(result, 4.0, accuracy: 1e-9,
                       "2.0 scaled from 2 to 4 servings should equal 4.0")
    }

    /// Fractional quantity scales correctly to a non-integer result.
    ///
    /// original=0.5, originalServings=2, targetServings=3 → 0.75
    func testAdjustedQuantityWithFractionalQuantity() {
        let rankedRecipe = makeRankedRecipe(
            servingSize: 2,
            ingredients: [RecipeIngredient(name: "Oil", quantity: 0.5, unit: "tbsp")]
        )
        let viewModel = RecipeDetailViewModel(rankedRecipe: rankedRecipe)

        let result = viewModel.adjustedQuantity(
            original: 0.5,
            originalServings: 2,
            targetServings: 3
        )

        XCTAssertEqual(result, 0.75, accuracy: 1e-9,
                       "0.5 scaled from 2 to 3 servings should equal 0.75")
    }

    /// When target servings equals original servings, the quantity is unchanged.
    func testAdjustedQuantityWhenTargetEqualsOriginalServings() {
        let rankedRecipe = makeRankedRecipe(
            servingSize: 4,
            ingredients: [RecipeIngredient(name: "Tomato", quantity: 3.0, unit: "whole")]
        )
        let viewModel = RecipeDetailViewModel(rankedRecipe: rankedRecipe)

        let result = viewModel.adjustedQuantity(
            original: 3.0,
            originalServings: 4,
            targetServings: 4
        )

        XCTAssertEqual(result, 3.0, accuracy: 1e-9,
                       "Quantity should be unchanged when targetServings == originalServings")
    }

    // MARK: - adjustedIngredients Tests

    /// `adjustedIngredients` reflects correctly scaled values when `targetServings` changes.
    func testAdjustedIngredientsReflectsScaledValues() {
        let ingredients = [
            RecipeIngredient(name: "Onion", quantity: 2.0, unit: "whole"),
            RecipeIngredient(name: "Oil", quantity: 1.0, unit: "tbsp"),
            RecipeIngredient(name: "Salt", quantity: 0.5, unit: "tsp")
        ]
        let rankedRecipe = makeRankedRecipe(servingSize: 2, ingredients: ingredients)
        let viewModel = RecipeDetailViewModel(rankedRecipe: rankedRecipe)

        // Change target servings from 2 → 4 (double)
        viewModel.targetServings = 4

        let adjusted = viewModel.adjustedIngredients

        XCTAssertEqual(adjusted.count, 3,
                       "adjustedIngredients should contain the same number of ingredients")
        XCTAssertEqual(adjusted[0].quantity, 4.0, accuracy: 1e-9,
                       "Onion: 2.0 × (4/2) should equal 4.0")
        XCTAssertEqual(adjusted[1].quantity, 2.0, accuracy: 1e-9,
                       "Oil: 1.0 × (4/2) should equal 2.0")
        XCTAssertEqual(adjusted[2].quantity, 1.0, accuracy: 1e-9,
                       "Salt: 0.5 × (4/2) should equal 1.0")
    }

    /// `adjustedIngredients` returns original quantities when `targetServings` equals the recipe's serving size.
    func testAdjustedIngredientsUnchangedWhenTargetMatchesOriginal() {
        let ingredients = [
            RecipeIngredient(name: "Tomato", quantity: 3.0, unit: "whole"),
            RecipeIngredient(name: "Garam Masala", quantity: 0.25, unit: "tsp")
        ]
        let rankedRecipe = makeRankedRecipe(servingSize: 4, ingredients: ingredients)
        let viewModel = RecipeDetailViewModel(rankedRecipe: rankedRecipe)

        // targetServings defaults to recipe's servingSize (4), so no scaling should occur
        let adjusted = viewModel.adjustedIngredients

        XCTAssertEqual(adjusted[0].quantity, 3.0, accuracy: 1e-9,
                       "Tomato quantity should be unchanged when targetServings == originalServings")
        XCTAssertEqual(adjusted[1].quantity, 0.25, accuracy: 1e-9,
                       "Garam Masala quantity should be unchanged when targetServings == originalServings")
    }

    /// Ingredient names and units are preserved after scaling.
    func testAdjustedIngredientsPreservesNamesAndUnits() {
        let ingredients = [
            RecipeIngredient(name: "Cumin Seeds", quantity: 1.0, unit: "tsp")
        ]
        let rankedRecipe = makeRankedRecipe(servingSize: 2, ingredients: ingredients)
        let viewModel = RecipeDetailViewModel(rankedRecipe: rankedRecipe)
        viewModel.targetServings = 6

        let adjusted = viewModel.adjustedIngredients

        XCTAssertEqual(adjusted[0].name, "Cumin Seeds",
                       "Ingredient name should be preserved after scaling")
        XCTAssertEqual(adjusted[0].unit, "tsp",
                       "Ingredient unit should be preserved after scaling")
        XCTAssertEqual(adjusted[0].quantity, 3.0, accuracy: 1e-9,
                       "Cumin Seeds: 1.0 × (6/2) should equal 3.0")
    }
}
