// Enums.swift
// ChefNova
//
// Core enums and type aliases for the ChefNova domain model.

import Foundation

/// A canonical ingredient name — always normalized via the synonym dictionary.
typealias CanonicalIngredient = String

/// Supported cuisine types for recipe generation and pantry staples lookup.
enum Cuisine: String, Codable, CaseIterable {
    case northIndian = "North Indian"
}

/// Dietary classification filter for recipe generation.
enum DietaryPreference: String, Codable, CaseIterable {
    case vegetarian = "Vegetarian"
    case nonVegetarian = "Non-Vegetarian"
}

/// Cooking proficiency tier used to filter recipe complexity.
enum SkillLevel: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediatePro = "Intermediate/Pro"
    case chefLevel = "Chef Level"
}
