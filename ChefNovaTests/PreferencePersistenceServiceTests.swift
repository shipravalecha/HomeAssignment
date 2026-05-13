// PreferencePersistenceServiceTests.swift
// ChefNovaTests
//
// Property-based test for PreferencePersistenceService.
// Validates: Requirements 2.5, 3.6, 8.1, 8.2, 8.4

import XCTest
import SwiftCheck
import SwiftData
@testable import ChefNova

// MARK: - Input wrapper for the round-trip property

/// Wraps the three preference inputs so SwiftCheck can generate them as a single value.
private struct PreferenceInput {
    let cuisine: Cuisine
    let dietaryPreference: DietaryPreference?
    let skillLevel: SkillLevel
}

extension PreferenceInput: Arbitrary {
    static var arbitrary: Gen<PreferenceInput> {
        // Generator for Cuisine — pick any case from the CaseIterable enum.
        let cuisineGen = Gen<Cuisine>.fromElements(of: Cuisine.allCases)

        // Generator for optional DietaryPreference — nil represents "no preference".
        // one(of:) gives equal weight to nil and any non-nil case.
        let dietaryPrefGen: Gen<DietaryPreference?> = Gen<DietaryPreference?>.one(of: [
            Gen.pure(nil),
            Gen<DietaryPreference>.fromElements(of: DietaryPreference.allCases).map { Optional($0) }
        ])

        // Generator for SkillLevel — pick any case from the CaseIterable enum.
        let skillLevelGen = Gen<SkillLevel>.fromElements(of: SkillLevel.allCases)

        return cuisineGen.flatMap { cuisine in
            dietaryPrefGen.flatMap { dietaryPref in
                skillLevelGen.map { skillLevel in
                    PreferenceInput(
                        cuisine: cuisine,
                        dietaryPreference: dietaryPref,
                        skillLevel: skillLevel
                    )
                }
            }
        }
    }
}

// MARK: - Unit Tests for PreferencePersistenceService

final class PreferencePersistenceServiceTests: XCTestCase {

    // MARK: - Helpers

    /// Creates an isolated in-memory SwiftData container for each test.
    @MainActor
    private func makeInMemoryService() throws -> (PreferencePersistenceService, ModelContainer) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PreferenceProfile.self, configurations: config)
        let context = ModelContext(container)
        let service = PreferencePersistenceService(context: context)
        return (service, container)
    }

    // MARK: - Unit Test: Save-then-load round-trip
    //
    // Validates: Requirements 8.1, 8.2
    //
    // Saving a concrete PreferenceProfile and then calling loadLatestPreferences
    // SHALL return a profile with equal cuisine, dietaryPreference, and skillLevel values.
    @MainActor
    func testSaveThenLoadRoundTrip() throws {
        let (service, _) = try makeInMemoryService()

        let profile = PreferenceProfile(
            cuisine: Cuisine.northIndian.rawValue,
            dietaryPreference: DietaryPreference.vegetarian.rawValue,
            skillLevel: SkillLevel.beginner.rawValue
        )

        try service.savePreferences(profile)

        let loaded = service.loadLatestPreferences()

        XCTAssertNotNil(loaded, "loadLatestPreferences should return a profile after saving")
        XCTAssertEqual(loaded?.cuisine, Cuisine.northIndian.rawValue)
        XCTAssertEqual(loaded?.dietaryPreference, DietaryPreference.vegetarian.rawValue)
        XCTAssertEqual(loaded?.skillLevel, SkillLevel.beginner.rawValue)
    }

    // MARK: - Unit Test: Save-then-load round-trip with nil dietary preference
    //
    // Validates: Requirements 8.1, 8.2, 8.4
    //
    // A profile saved with no dietary preference (nil) SHALL round-trip correctly.
    @MainActor
    func testSaveThenLoadRoundTripNilDietaryPreference() throws {
        let (service, _) = try makeInMemoryService()

        let profile = PreferenceProfile(
            cuisine: Cuisine.northIndian.rawValue,
            dietaryPreference: nil,
            skillLevel: SkillLevel.chefLevel.rawValue
        )

        try service.savePreferences(profile)

        let loaded = service.loadLatestPreferences()

        XCTAssertNotNil(loaded, "loadLatestPreferences should return a profile after saving")
        XCTAssertEqual(loaded?.cuisine, Cuisine.northIndian.rawValue)
        XCTAssertNil(loaded?.dietaryPreference, "dietaryPreference should be nil when saved as nil")
        XCTAssertEqual(loaded?.skillLevel, SkillLevel.chefLevel.rawValue)
    }

    // MARK: - Unit Test: Second save overwrites; loadLatestPreferences returns newer values
    //
    // Validates: Requirements 8.1, 8.2, 8.4
    //
    // When a second PreferenceProfile is saved after a first, loadLatestPreferences
    // SHALL return the values from the second (most recent) save.
    @MainActor
    func testSecondSaveOverwritesAndReturnsNewerValues() throws {
        let (service, _) = try makeInMemoryService()

        // Save the first profile.
        let firstProfile = PreferenceProfile(
            cuisine: Cuisine.northIndian.rawValue,
            dietaryPreference: DietaryPreference.vegetarian.rawValue,
            skillLevel: SkillLevel.beginner.rawValue
        )
        try service.savePreferences(firstProfile)

        // Introduce a small delay so savedAt timestamps differ.
        Thread.sleep(forTimeInterval: 0.01)

        // Save the second profile with different values.
        let secondProfile = PreferenceProfile(
            cuisine: Cuisine.northIndian.rawValue,
            dietaryPreference: DietaryPreference.nonVegetarian.rawValue,
            skillLevel: SkillLevel.intermediatePro.rawValue
        )
        try service.savePreferences(secondProfile)

        // loadLatestPreferences must return the second (newer) profile's values.
        let loaded = service.loadLatestPreferences()

        XCTAssertNotNil(loaded, "loadLatestPreferences should return a profile after saving")
        XCTAssertEqual(
            loaded?.dietaryPreference,
            DietaryPreference.nonVegetarian.rawValue,
            "Should return the dietary preference from the most recent save"
        )
        XCTAssertEqual(
            loaded?.skillLevel,
            SkillLevel.intermediatePro.rawValue,
            "Should return the skill level from the most recent save"
        )
    }

    // MARK: - Unit Test: Load returns nil when no profile has been saved
    //
    // Validates: Requirements 8.2
    //
    // loadLatestPreferences SHALL return nil when the store is empty.
    @MainActor
    func testLoadReturnsNilWhenNoProfileSaved() throws {
        let (service, _) = try makeInMemoryService()

        let loaded = service.loadLatestPreferences()

        XCTAssertNil(loaded, "loadLatestPreferences should return nil when no profile has been saved")
    }

    // MARK: - Property-Based Test: Preference Profile Round-Trip

    // Feature: chef-nova-app, Property 9: Preference profile round-trip
    //
    // Validates: Requirements 2.5, 3.6, 8.1, 8.2, 8.4
    //
    // Property 9: Preference Profile Round-Trip
    // For any valid combination of Cuisine, DietaryPreference? (including nil),
    // and SkillLevel, saving that combination as a PreferenceProfile and then
    // loading the most recent PreferenceProfile SHALL return values equal to
    // the saved combination.
    @MainActor
    func testPreferenceProfileRoundTrip() throws {
        // Build an in-memory SwiftData container for isolation.
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PreferenceProfile.self, configurations: config)

        property(
            "saving then loading a PreferenceProfile returns equal values",
            arguments: CheckerArguments(maxAllowableSuccessfulTests: 100)
        ) <- forAll { [container] (input: PreferenceInput) in
            // Each iteration uses a fresh context so tests are fully isolated.
            let context = ModelContext(container)
            let service = PreferencePersistenceService(context: context)

            // Build and save the profile using the raw String values stored by PreferenceProfile.
            let profile = PreferenceProfile(
                cuisine: input.cuisine.rawValue,
                dietaryPreference: input.dietaryPreference?.rawValue,
                skillLevel: input.skillLevel.rawValue
            )

            do {
                try service.savePreferences(profile)
            } catch {
                // A save failure is a test infrastructure problem, not a property violation.
                return false
            }

            // Load the most recently saved profile.
            guard let loaded = service.loadLatestPreferences() else {
                // loadLatestPreferences must return a value after a successful save.
                return false
            }

            // Assert all three fields round-trip correctly.
            let cuisineMatches = loaded.cuisine == input.cuisine.rawValue
            let dietaryMatches = loaded.dietaryPreference == input.dietaryPreference?.rawValue
            let skillMatches = loaded.skillLevel == input.skillLevel.rawValue

            return cuisineMatches && dietaryMatches && skillMatches
        }
    }
}
