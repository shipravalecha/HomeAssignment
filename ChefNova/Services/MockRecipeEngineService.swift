// MockRecipeEngineService.swift
// ChefNova
//
// A deterministic mock implementation of RecipeEngineServiceProtocol used
// during UI testing. Activated when the app is launched with the
// "--uitesting" launch argument.
//
// This file is compiled into the main app target so that XCUITest can
// exercise the real SwiftUI view hierarchy with predictable data.

import Foundation

#if DEBUG

/// A mock `RecipeEngineServiceProtocol` that returns a fixed set of
/// pre-canned `RankedRecipe` values without making any network calls.
///
/// Used exclusively during UI testing (when the app is launched with
/// `--uitesting`). The returned recipes cover both full-match and
/// partial-match scenarios so the UI test can verify all card elements.
///
/// When `shouldThrowNetworkError` is `true` (activated via the
/// `--uitesting-network-error` launch argument), the service throws
/// `RecipeEngineError.networkUnavailable` instead of returning recipes.
final class MockRecipeEngineService: RecipeEngineServiceProtocol {

    /// When `true`, `generateRecipes` throws `RecipeEngineError.networkUnavailable`.
    let shouldThrowNetworkError: Bool

    init(shouldThrowNetworkError: Bool = false) {
        self.shouldThrowNetworkError = shouldThrowNetworkError
    }

    @MainActor
    func generateRecipes(request: RecipeGenerationRequest) async throws -> [RankedRecipe] {
        // Simulate a brief delay so the loading state is visible.
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 s

        if shouldThrowNetworkError {
            throw RecipeEngineError.networkUnavailable
        }

        return Self.sampleRecipes
    }

    // MARK: - Sample data

    static let sampleRecipes: [RankedRecipe] = [
        // Full match — 100 %
        RankedRecipe(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            recipe: Recipe(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                title: "Aloo Gobi",
                cuisine: .northIndian,
                dietaryClassification: .vegetarian,
                skillLevel: .beginner,
                prepTimeMinutes: 10,
                cookTimeMinutes: 20,
                servingSize: 2,
                ingredients: [
                    RecipeIngredient(name: "Potato", quantity: 2, unit: "pieces"),
                    RecipeIngredient(name: "Cauliflower", quantity: 1, unit: "head")
                ],
                steps: ["Chop vegetables.", "Cook in a pan with spices."]
            ),
            matchScore: 1.0,
            isPartialMatch: false,
            gapIngredients: []
        ),
        // Partial match — 75 %
        RankedRecipe(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            recipe: Recipe(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                title: "Palak Paneer",
                cuisine: .northIndian,
                dietaryClassification: .vegetarian,
                skillLevel: .beginner,
                prepTimeMinutes: 15,
                cookTimeMinutes: 25,
                servingSize: 4,
                ingredients: [
                    RecipeIngredient(name: "Spinach", quantity: 200, unit: "g"),
                    RecipeIngredient(name: "Paneer", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "Onion", quantity: 1, unit: "piece"),
                    RecipeIngredient(name: "Tomato", quantity: 1, unit: "piece")
                ],
                steps: ["Blanch spinach.", "Fry paneer.", "Combine with masala."]
            ),
            matchScore: 0.75,
            isPartialMatch: true,
            gapIngredients: [
                GapIngredient(
                    name: "Paneer",
                    commonalityRank: 1,
                    purchaseSearchURL: URL(string: "https://www.google.com/search?q=buy+Paneer")!
                )
            ]
        ),
        // Partial match — 50 %
        RankedRecipe(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            recipe: Recipe(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                title: "Dal Makhani",
                cuisine: .northIndian,
                dietaryClassification: .vegetarian,
                skillLevel: .intermediatePro,
                prepTimeMinutes: 20,
                cookTimeMinutes: 40,
                servingSize: 3,
                ingredients: [
                    RecipeIngredient(name: "Black Lentils", quantity: 1, unit: "cup"),
                    RecipeIngredient(name: "Butter", quantity: 2, unit: "tbsp"),
                    RecipeIngredient(name: "Cream", quantity: 50, unit: "ml"),
                    RecipeIngredient(name: "Tomato", quantity: 2, unit: "pieces")
                ],
                steps: ["Soak lentils overnight.", "Cook with butter and cream."]
            ),
            matchScore: 0.5,
            isPartialMatch: true,
            gapIngredients: [
                GapIngredient(
                    name: "Black Lentils",
                    commonalityRank: 1,
                    purchaseSearchURL: URL(string: "https://www.google.com/search?q=buy+Black+Lentils")!
                ),
                GapIngredient(
                    name: "Cream",
                    commonalityRank: 2,
                    purchaseSearchURL: URL(string: "https://www.google.com/search?q=buy+Cream")!
                )
            ]
        )
    ]
}

#endif
