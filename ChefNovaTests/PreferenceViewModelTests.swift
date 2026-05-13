// PreferenceViewModelTests.swift
// ChefNovaTests
//
// Unit tests for PreferenceViewModel.
// Validates: Requirements 2.3, 2.5, 3.6, 8.1

import XCTest
@testable import ChefNova

// MARK: - Mock PreferencePersistenceService

/// A test double for `PreferencePersistenceServiceProtocol` that stores
/// profiles in memory without touching SwiftData. This keeps the tests
/// fast, deterministic, and fully isolated.
private final class MockPreferencePersistenceService: PreferencePersistenceServiceProtocol {

    /// The profiles saved via `savePreferences(_:)`, in insertion order.
    private(set) var savedProfiles: [PreferenceProfile] = []

    /// The profile returned by `loadLatestPreferences()`. Set this before
    /// creating the view model to simulate a pre-existing saved profile.
    var profileToReturn: PreferenceProfile?

    /// Whether `savePreferences(_:)` should throw an error.
    var shouldThrowOnSave: Bool = false

    func savePreferences(_ profile: PreferenceProfile) throws {
        if shouldThrowOnSave {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
        savedProfiles.append(profile)
    }

    func loadLatestPreferences() -> PreferenceProfile? {
        profileToReturn
    }
}

// MARK: - PreferenceViewModelTests

/// Unit tests for `PreferenceViewModel`.
///
/// Each test uses a `MockPreferencePersistenceService` injected at init so
/// the view model's logic is exercised in isolation from SwiftData.
///
/// Validates: Requirements 2.3, 2.5, 3.6, 8.1
@MainActor
final class PreferenceViewModelTests: XCTestCase {

    // MARK: - Helpers

    /// Returns a view model backed by the given mock service.
    private func makeViewModel(
        mock: MockPreferencePersistenceService = MockPreferencePersistenceService()
    ) -> PreferenceViewModel {
        PreferenceViewModel(persistenceService: mock)
    }

    // MARK: - Pre-population (Requirements 2.5, 3.6)

    /// When a saved profile exists, `init` SHALL pre-populate `selectedCuisine`,
    /// `selectedDietaryPreference`, and `selectedSkillLevel` from that profile.
    ///
    /// Validates: Requirements 2.5, 3.6
    func testPrePopulatesSelectorsWhenSavedProfileExists() {
        let mock = MockPreferencePersistenceService()
        mock.profileToReturn = PreferenceProfile(
            cuisine: Cuisine.northIndian.rawValue,
            dietaryPreference: DietaryPreference.vegetarian.rawValue,
            skillLevel: SkillLevel.intermediatePro.rawValue
        )

        let viewModel = makeViewModel(mock: mock)

        XCTAssertEqual(viewModel.selectedCuisine, .northIndian,
                       "selectedCuisine should be pre-populated from the saved profile")
        XCTAssertEqual(viewModel.selectedDietaryPreference, .vegetarian,
                       "selectedDietaryPreference should be pre-populated from the saved profile")
        XCTAssertEqual(viewModel.selectedSkillLevel, .intermediatePro,
                       "selectedSkillLevel should be pre-populated from the saved profile")
    }

    /// When a saved profile has a nil dietary preference, `selectedDietaryPreference`
    /// SHALL remain nil after pre-population.
    ///
    /// Validates: Requirements 2.5, 3.6
    func testPrePopulatesNilDietaryPreferenceWhenSavedProfileHasNone() {
        let mock = MockPreferencePersistenceService()
        mock.profileToReturn = PreferenceProfile(
            cuisine: Cuisine.northIndian.rawValue,
            dietaryPreference: nil,
            skillLevel: SkillLevel.chefLevel.rawValue
        )

        let viewModel = makeViewModel(mock: mock)

        XCTAssertEqual(viewModel.selectedCuisine, .northIndian,
                       "selectedCuisine should be pre-populated from the saved profile")
        XCTAssertNil(viewModel.selectedDietaryPreference,
                     "selectedDietaryPreference should be nil when the saved profile has no dietary preference")
        XCTAssertEqual(viewModel.selectedSkillLevel, .chefLevel,
                       "selectedSkillLevel should be pre-populated from the saved profile")
    }

    /// When no saved profile exists, selectors SHALL remain at their default values:
    /// `selectedCuisine` is nil, `selectedDietaryPreference` is nil, and
    /// `selectedSkillLevel` is `.beginner`.
    ///
    /// Validates: Requirements 2.5, 3.6
    func testSelectorsRemainAtDefaultsWhenNoSavedProfileExists() {
        let mock = MockPreferencePersistenceService()
        // profileToReturn is nil by default — no saved profile.

        let viewModel = makeViewModel(mock: mock)

        XCTAssertNil(viewModel.selectedCuisine,
                     "selectedCuisine should be nil when no saved profile exists")
        XCTAssertNil(viewModel.selectedDietaryPreference,
                     "selectedDietaryPreference should be nil when no saved profile exists")
        XCTAssertEqual(viewModel.selectedSkillLevel, .beginner,
                       "selectedSkillLevel should default to .beginner when no saved profile exists")
    }

    // MARK: - validateForSubmission() (Requirement 2.3)

    /// `validateForSubmission()` SHALL return `false` and set `validationError`
    /// when no cuisine has been selected.
    ///
    /// Validates: Requirement 2.3
    func testValidateForSubmissionReturnsFalseWhenNoCuisineSelected() {
        let viewModel = makeViewModel()
        // selectedCuisine is nil by default.

        let result = viewModel.validateForSubmission()

        XCTAssertFalse(result,
                       "validateForSubmission() should return false when no cuisine is selected")
        XCTAssertNotNil(viewModel.validationError,
                        "validationError should be set when no cuisine is selected")
    }

    /// `validateForSubmission()` SHALL return `true` and clear `validationError`
    /// when a cuisine has been selected.
    ///
    /// Validates: Requirement 2.3
    func testValidateForSubmissionReturnsTrueWhenCuisineIsSelected() {
        let viewModel = makeViewModel()
        viewModel.selectedCuisine = .northIndian

        let result = viewModel.validateForSubmission()

        XCTAssertTrue(result,
                      "validateForSubmission() should return true when a cuisine is selected")
        XCTAssertNil(viewModel.validationError,
                     "validationError should be nil when validation passes")
    }

    /// A prior validation error is cleared when `validateForSubmission()` is
    /// called again after a cuisine has been selected.
    ///
    /// Validates: Requirement 2.3
    func testValidateForSubmissionClearsPriorErrorAfterCuisineSelected() {
        let viewModel = makeViewModel()

        // First call: no cuisine → sets error.
        _ = viewModel.validateForSubmission()
        XCTAssertNotNil(viewModel.validationError)

        // Select a cuisine, then validate again.
        viewModel.selectedCuisine = .northIndian
        let result = viewModel.validateForSubmission()

        XCTAssertTrue(result,
                      "validateForSubmission() should return true after a cuisine is selected")
        XCTAssertNil(viewModel.validationError,
                     "validationError should be cleared when validation passes on the second call")
    }

    // MARK: - savePreferences() (Requirements 2.5, 8.1)

    /// `savePreferences()` SHALL persist the current selections by calling
    /// `PreferencePersistenceServiceProtocol.savePreferences(_:)` with a
    /// profile that reflects the current cuisine, dietary preference, and
    /// skill level.
    ///
    /// Validates: Requirements 2.5, 8.1
    func testSavePreferencesPersistsCurrentSelections() {
        let mock = MockPreferencePersistenceService()
        let viewModel = makeViewModel(mock: mock)

        viewModel.selectedCuisine = .northIndian
        viewModel.selectedDietaryPreference = .nonVegetarian
        viewModel.selectedSkillLevel = .chefLevel

        viewModel.savePreferences()

        XCTAssertEqual(mock.savedProfiles.count, 1,
                       "savePreferences() should call the persistence service exactly once")

        let saved = mock.savedProfiles.first
        XCTAssertEqual(saved?.cuisine, Cuisine.northIndian.rawValue,
                       "Saved profile should contain the selected cuisine")
        XCTAssertEqual(saved?.dietaryPreference, DietaryPreference.nonVegetarian.rawValue,
                       "Saved profile should contain the selected dietary preference")
        XCTAssertEqual(saved?.skillLevel, SkillLevel.chefLevel.rawValue,
                       "Saved profile should contain the selected skill level")
    }

    /// `savePreferences()` SHALL persist a nil dietary preference when the
    /// user has not selected one.
    ///
    /// Validates: Requirements 2.5, 8.1
    func testSavePreferencesPersistsNilDietaryPreference() {
        let mock = MockPreferencePersistenceService()
        let viewModel = makeViewModel(mock: mock)

        viewModel.selectedCuisine = .northIndian
        viewModel.selectedDietaryPreference = nil
        viewModel.selectedSkillLevel = .beginner

        viewModel.savePreferences()

        XCTAssertEqual(mock.savedProfiles.count, 1,
                       "savePreferences() should call the persistence service exactly once")

        let saved = mock.savedProfiles.first
        XCTAssertNil(saved?.dietaryPreference,
                     "Saved profile should have nil dietaryPreference when none was selected")
    }

    /// `savePreferences()` SHALL NOT call the persistence service when no
    /// cuisine has been selected (guard against saving an incomplete profile).
    ///
    /// Validates: Requirement 8.1
    func testSavePreferencesDoesNotPersistWhenNoCuisineSelected() {
        let mock = MockPreferencePersistenceService()
        let viewModel = makeViewModel(mock: mock)
        // selectedCuisine is nil by default.

        viewModel.savePreferences()

        XCTAssertTrue(mock.savedProfiles.isEmpty,
                      "savePreferences() should not persist when no cuisine is selected")
    }

    /// `savePreferences()` SHALL silently ignore persistence errors without
    /// surfacing them to the caller.
    ///
    /// Validates: Requirement 8.1
    func testSavePreferencesSilentlyIgnoresPersistenceErrors() {
        let mock = MockPreferencePersistenceService()
        mock.shouldThrowOnSave = true
        let viewModel = makeViewModel(mock: mock)

        viewModel.selectedCuisine = .northIndian

        // This must not throw or crash.
        XCTAssertNoThrow(viewModel.savePreferences(),
                         "savePreferences() should silently ignore persistence errors")
    }

    // MARK: - Round-trip: save then pre-populate (Requirements 2.5, 3.6, 8.1)

    /// Saving preferences and then creating a new view model with the saved
    /// profile SHALL pre-populate the selectors with the saved values.
    ///
    /// Validates: Requirements 2.5, 3.6, 8.1
    func testSavedPreferencesArePrePopulatedOnNextInit() {
        let mock = MockPreferencePersistenceService()
        let firstViewModel = makeViewModel(mock: mock)

        // Set and save preferences in the first session.
        firstViewModel.selectedCuisine = .northIndian
        firstViewModel.selectedDietaryPreference = .vegetarian
        firstViewModel.selectedSkillLevel = .intermediatePro
        firstViewModel.savePreferences()

        // Simulate a new app launch: configure the mock to return the saved profile.
        let savedProfile = mock.savedProfiles.first
        mock.profileToReturn = savedProfile

        // Create a new view model — it should pre-populate from the saved profile.
        let secondViewModel = makeViewModel(mock: mock)

        XCTAssertEqual(secondViewModel.selectedCuisine, .northIndian,
                       "selectedCuisine should be pre-populated from the previously saved profile")
        XCTAssertEqual(secondViewModel.selectedDietaryPreference, .vegetarian,
                       "selectedDietaryPreference should be pre-populated from the previously saved profile")
        XCTAssertEqual(secondViewModel.selectedSkillLevel, .intermediatePro,
                       "selectedSkillLevel should be pre-populated from the previously saved profile")
    }
}
