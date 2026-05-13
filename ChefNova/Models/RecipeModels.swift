// RecipeModels.swift
// ChefNova
//
// Core recipe domain models used throughout the app.

import Foundation

/// A single ingredient entry within a recipe, including its quantity and unit.
struct RecipeIngredient: Codable, Equatable {
    let name: CanonicalIngredient
    let quantity: Double
    let unit: String
}

/// A fully structured recipe returned by the Recipe Engine.
struct Recipe: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let cuisine: Cuisine
    let dietaryClassification: DietaryPreference
    let skillLevel: SkillLevel
    let prepTimeMinutes: Int
    let cookTimeMinutes: Int
    let servingSize: Int
    let ingredients: [RecipeIngredient]
    let steps: [String]
}

/// A recipe decorated with its match score and gap ingredient information.
struct RankedRecipe: Identifiable, Equatable {
    let id: UUID
    let recipe: Recipe
    /// Match score in the range 0.0 – 1.0.
    let matchScore: Double
    let isPartialMatch: Bool
    /// Empty for full matches; populated for partial matches.
    let gapIngredients: [GapIngredient]
}

/// An ingredient the user does not have that is required to complete a partial match recipe.
struct GapIngredient: Equatable {
    let name: CanonicalIngredient
    /// Lower value indicates a more commonly available ingredient.
    let commonalityRank: Int
    let purchaseSearchURL: URL
}

/// The input payload sent to `RecipeEngineService` to generate recipe suggestions.
struct RecipeGenerationRequest {
    /// Canonical ingredient names provided by the user.
    let ingredients: [String]
    /// Pantry staples for the selected cuisine, treated as implicitly available.
    let pantryStaples: [String]
    let cuisine: Cuisine
    let dietaryPreference: DietaryPreference?
    let skillLevel: SkillLevel
}
