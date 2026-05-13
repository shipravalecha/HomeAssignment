// PreferenceViewModel.swift
// ChefNova
//
// ViewModel for the Preference Selection screen. Manages cuisine, dietary
// preference, and skill level selections, persists them via
// PreferencePersistenceServiceProtocol, and exposes validation errors.
//
// Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.5, 3.6, 8.1, 8.2

import Foundation
import Observation

/// View model for the preference selection screen.
///
/// Pre-populates selectors from the most recently saved `PreferenceProfile`
/// on initialisation and persists changes via `PreferencePersistenceServiceProtocol`.
@MainActor
@Observable
final class PreferenceViewModel {

    // MARK: - State

    /// The cuisine selected by the user. `nil` until a selection is made.
    var selectedCuisine: Cuisine?

    /// The dietary preference selected by the user. `nil` means no preference.
    var selectedDietaryPreference: DietaryPreference?

    /// The cooking skill level selected by the user. Defaults to `.beginner`.
    var selectedSkillLevel: SkillLevel = .beginner

    /// A validation error message shown when cuisine has not been selected.
    var validationError: String?

    // MARK: - Dependencies

    private let persistenceService: PreferencePersistenceServiceProtocol

    // MARK: - Init

    /// Creates the view model with the given persistence service.
    ///
    /// Immediately attempts to load the most recently saved preferences and
    /// pre-populates the selectors if a profile is found.
    ///
    /// - Parameter persistenceService: The service used to save and load
    ///   preference profiles.
    init(persistenceService: PreferencePersistenceServiceProtocol) {
        self.persistenceService = persistenceService
        loadSavedPreferences()
    }

    // MARK: - Methods

    /// Constructs a `PreferenceProfile` from the current selections and
    /// persists it via the persistence service.
    ///
    /// Errors from the persistence layer are silently ignored to avoid
    /// surfacing storage failures to the user during normal operation.
    func savePreferences() {
        guard let cuisine = selectedCuisine else { return }
        let profile = PreferenceProfile(
            cuisine: cuisine.rawValue,
            dietaryPreference: selectedDietaryPreference?.rawValue,
            skillLevel: selectedSkillLevel.rawValue
        )
        do {
            try persistenceService.savePreferences(profile)
        } catch {
            // Silently ignore persistence errors — the user's session is
            // unaffected even if the save fails.
        }
    }

    /// Validates that a cuisine has been selected before recipe submission.
    ///
    /// - Returns: `true` if `selectedCuisine` is non-nil; `false` otherwise.
    ///   Sets `validationError` to a user-facing message when returning `false`,
    ///   or clears it when returning `true`.
    @discardableResult
    func validateForSubmission() -> Bool {
        if selectedCuisine == nil {
            validationError = "Please select a cuisine to continue."
            return false
        }
        validationError = nil
        return true
    }

    // MARK: - Private Helpers

    /// Loads the most recently saved preference profile and pre-populates
    /// the selector properties if a profile exists.
    private func loadSavedPreferences() {
        guard let profile = persistenceService.loadLatestPreferences() else { return }
        selectedCuisine = Cuisine(rawValue: profile.cuisine)
        if let rawDietary = profile.dietaryPreference {
            selectedDietaryPreference = DietaryPreference(rawValue: rawDietary)
        }
        selectedSkillLevel = SkillLevel(rawValue: profile.skillLevel) ?? .beginner
    }
}
