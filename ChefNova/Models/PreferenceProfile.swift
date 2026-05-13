// PreferenceProfile.swift
// ChefNova
//
// SwiftData persistence model for the user's preference profile.

import Foundation
import SwiftData

/// Persisted record of the user's most recent cuisine, dietary preference, and skill level selections.
@Model
final class PreferenceProfile {
    var cuisine: String
    /// `nil` indicates no dietary preference was selected.
    var dietaryPreference: String?
    var skillLevel: String
    var savedAt: Date

    init(cuisine: String, dietaryPreference: String?, skillLevel: String) {
        self.cuisine = cuisine
        self.dietaryPreference = dietaryPreference
        self.skillLevel = skillLevel
        self.savedAt = Date()
    }
}
