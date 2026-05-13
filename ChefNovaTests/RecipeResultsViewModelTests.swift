// RecipeResultsViewModelTests.swift
// ChefNovaTests
//
// Unit tests for RecipeResultsViewModel.
// Validates: Requirements 4.1, 9.2, 9.3

import XCTest
@testable import ChefNova

// MARK: - Mock RecipeEngineService

/// A test double for `RecipeEngineServiceProtocol` that returns a configurable
/// result or throws a configurable error, without making any network calls.
private final class MockRecipeEngineService: RecipeEngineServiceProtocol {

    /// When non-nil, `generateRecipes` returns this array.
    var recipesToReturn: [RankedRecipe]?

    /// When non-nil, `generateRecipes` throws this error.
    var errorToThrow: Error?

    @MainActor
    func generateRecipes(request: RecipeGenerationRequest) async throws -> [RankedRecipe] {
        if let error = errorToThrow {
            throw error
        }
        return recipesToReturn ?? []
    }
}

// MARK: - Mock PantryStaplesService

/// A test double for `PantryStaplesServiceProtocol` that returns a fixed list
/// of pantry staples without loading any JSON bundle resource.
private final class MockPantryStaplesService: PantryStaplesServiceProtocol {

    /// The staples returned by `getPantryStaples(for:)`.
    var staplesToReturn: [String] = ["Salt", "Oil"]

    func getPantryStaples(for cuisine: Cuisine) -> [String] {
        staplesToReturn
    }

    func isPantryStaple(_ ingredient: String, for cuisine: Cuisine) -> Bool {
        staplesToReturn.map { $0.lowercased() }.contains(ingredient.lowercased())
    }
}

// MARK: - Mock PreferencePersistenceService

/// A test double for `PreferencePersistenceServiceProtocol` that stores
/// profiles in memory without touching SwiftData.
private final class MockPreferencePersistenceService: PreferencePersistenceServiceProtocol {

    private(set) var savedProfiles: [PreferenceProfile] = []
    var profileToReturn: PreferenceProfile?
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

// MARK: - RecipeResultsViewModelTests

/// Unit tests for `RecipeResultsViewModel`.
///
/// Each test uses mock service implementations injected at init so the view
/// model's orchestration logic is exercised in isolation from real network
/// calls, bundle resources, and SwiftData.
///
/// Validates: Requirements 4.1, 9.2, 9.3
@MainActor
final class RecipeResultsViewModelTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a minimal `RankedRecipe` for use in mock service responses.
    private func makeSampleRankedRecipe(
        title: String = "Aloo Gobi",
        matchScore: Double = 1.0
    ) -> RankedRecipe {
        let recipe = Recipe(
            id: UUID(),
            title: title,
            cuisine: .northIndian,
            dietaryClassification: .vegetarian,
            skillLevel: .beginner,
            prepTimeMinutes: 10,
            cookTimeMinutes: 20,
            servingSize: 2,
            ingredients: [
                RecipeIngredient(name: "Onion", quantity: 1.0, unit: "piece")
            ],
            steps: ["Step 1"]
        )
        return RankedRecipe(
            id: recipe.id,
            recipe: recipe,
            matchScore: matchScore,
            isPartialMatch: matchScore < 1.0,
            gapIngredients: []
        )
    }

    /// Creates a `RecipeResultsViewModel` with the given mock services.
    private func makeViewModel(
        recipeEngine: any RecipeEngineServiceProtocol = MockRecipeEngineService(),
        pantryStaples: MockPantryStaplesService = MockPantryStaplesService(),
        persistence: MockPreferencePersistenceService = MockPreferencePersistenceService()
    ) -> RecipeResultsViewModel {
        RecipeResultsViewModel(
            recipeEngineService: recipeEngine,
            pantryStaplesService: pantryStaples,
            persistenceService: persistence
        )
    }

    /// A minimal set of generation parameters used across all tests.
    private var sampleIngredients: [String] { ["Onion", "Tomato"] }
    private var sampleCuisine: Cuisine { .northIndian }
    private var sampleDietaryPreference: DietaryPreference? { .vegetarian }
    private var sampleSkillLevel: SkillLevel { .beginner }

    // MARK: - Initial State

    /// The view model's initial state SHALL be `.idle`.
    ///
    /// Validates: Requirement 4.1
    func testInitialStateIsIdle() {
        let viewModel = makeViewModel()

        guard case .idle = viewModel.state else {
            XCTFail("Initial state should be .idle, got \(viewModel.state)")
            return
        }
    }

    // MARK: - Successful Generation (Requirements 4.1)

    /// On a successful generation, `state` SHALL transition to `.results`
    /// containing the ranked recipes returned by the service.
    ///
    /// Validates: Requirement 4.1
    func testSuccessfulGenerationTransitionsToResults() async {
        let mockEngine = MockRecipeEngineService()
        let expectedRecipe = makeSampleRankedRecipe(title: "Aloo Gobi", matchScore: 0.9)
        mockEngine.recipesToReturn = [expectedRecipe]

        let viewModel = makeViewModel(recipeEngine: mockEngine)

        await viewModel.generateRecipes(
            ingredients: sampleIngredients,
            cuisine: sampleCuisine,
            dietaryPreference: sampleDietaryPreference,
            skillLevel: sampleSkillLevel
        )

        guard case .results(let recipes) = viewModel.state else {
            XCTFail("State should be .results after a successful generation, got \(viewModel.state)")
            return
        }

        XCTAssertEqual(recipes.count, 1,
                       "Results should contain exactly 1 recipe")
        XCTAssertEqual(recipes.first?.recipe.title, "Aloo Gobi",
                       "The returned recipe title should match the mock's response")
        XCTAssertEqual(recipes.first?.matchScore ?? 0.0, 0.9, accuracy: 0.001,
                       "The returned match score should match the mock's response")
    }

    /// On a successful generation, `state` SHALL transition through `.loading`
    /// before reaching `.results`.
    ///
    /// This test captures the intermediate `.loading` state by observing the
    /// state immediately after the async call begins (before it completes).
    ///
    /// Validates: Requirement 4.1
    func testSuccessfulGenerationPassesThroughLoadingState() async {
        let mockEngine = MockRecipeEngineService()
        let expectedRecipe = makeSampleRankedRecipe()
        mockEngine.recipesToReturn = [expectedRecipe]

        let viewModel = makeViewModel(recipeEngine: mockEngine)

        // Capture the loading state by observing it inside a concurrent task
        // that starts the generation and immediately checks the state.
        var observedLoadingState = false

        // Use a continuation to observe the loading state mid-flight.
        let task = Task {
            await viewModel.generateRecipes(
                ingredients: sampleIngredients,
                cuisine: sampleCuisine,
                dietaryPreference: sampleDietaryPreference,
                skillLevel: sampleSkillLevel
            )
        }

        // The state is set to .loading synchronously at the start of
        // generateRecipes (before the first await), so we can check it
        // immediately after the task is created but before it completes.
        if case .loading = viewModel.state {
            observedLoadingState = true
        }

        await task.value

        XCTAssertTrue(observedLoadingState,
                      "State should pass through .loading before reaching .results")

        // Final state should be .results.
        guard case .results = viewModel.state else {
            XCTFail("Final state should be .results after successful generation")
            return
        }
    }

    /// On a successful generation with multiple recipes, all recipes SHALL be
    /// present in the `.results` state.
    ///
    /// Validates: Requirement 4.1
    func testSuccessfulGenerationWithMultipleRecipesReturnsAll() async {
        let mockEngine = MockRecipeEngineService()
        let recipes = [
            makeSampleRankedRecipe(title: "Recipe A", matchScore: 0.9),
            makeSampleRankedRecipe(title: "Recipe B", matchScore: 0.7),
            makeSampleRankedRecipe(title: "Recipe C", matchScore: 0.5)
        ]
        mockEngine.recipesToReturn = recipes

        let viewModel = makeViewModel(recipeEngine: mockEngine)

        await viewModel.generateRecipes(
            ingredients: sampleIngredients,
            cuisine: sampleCuisine,
            dietaryPreference: sampleDietaryPreference,
            skillLevel: sampleSkillLevel
        )

        guard case .results(let returnedRecipes) = viewModel.state else {
            XCTFail("State should be .results after a successful generation")
            return
        }

        XCTAssertEqual(returnedRecipes.count, 3,
                       "All 3 recipes should be present in the results")
    }

    // MARK: - Timeout Error (Requirement 9.2)

    /// When the service throws `RecipeEngineError.timeout`, `state` SHALL
    /// transition to `.error(.timeout)`.
    ///
    /// Validates: Requirement 9.2
    func testTimeoutErrorTransitionsToErrorTimeout() async {
        let mockEngine = MockRecipeEngineService()
        mockEngine.errorToThrow = RecipeEngineError.timeout

        let viewModel = makeViewModel(recipeEngine: mockEngine)

        await viewModel.generateRecipes(
            ingredients: sampleIngredients,
            cuisine: sampleCuisine,
            dietaryPreference: sampleDietaryPreference,
            skillLevel: sampleSkillLevel
        )

        guard case .error(let error) = viewModel.state else {
            XCTFail("State should be .error after a timeout, got \(viewModel.state)")
            return
        }

        guard case .timeout = error else {
            XCTFail("Error should be .timeout, got \(error)")
            return
        }
        // Success — state correctly reflects the timeout error.
    }

    // MARK: - Network Unavailable Error (Requirement 9.3)

    /// When the service throws `RecipeEngineError.networkUnavailable`, `state`
    /// SHALL transition to `.error(.networkUnavailable)`.
    ///
    /// Validates: Requirement 9.3
    func testNetworkUnavailableErrorTransitionsToErrorNetworkUnavailable() async {
        let mockEngine = MockRecipeEngineService()
        mockEngine.errorToThrow = RecipeEngineError.networkUnavailable

        let viewModel = makeViewModel(recipeEngine: mockEngine)

        await viewModel.generateRecipes(
            ingredients: sampleIngredients,
            cuisine: sampleCuisine,
            dietaryPreference: sampleDietaryPreference,
            skillLevel: sampleSkillLevel
        )

        guard case .error(let error) = viewModel.state else {
            XCTFail("State should be .error after a network unavailable error, got \(viewModel.state)")
            return
        }

        guard case .networkUnavailable = error else {
            XCTFail("Error should be .networkUnavailable, got \(error)")
            return
        }
        // Success — state correctly reflects the network unavailable error.
    }

    // MARK: - Server Error

    /// When the service throws `RecipeEngineError.serverError`, `state` SHALL
    /// transition to `.error(.serverError(...))`.
    func testServerErrorTransitionsToErrorServerError() async {
        let mockEngine = MockRecipeEngineService()
        mockEngine.errorToThrow = RecipeEngineError.serverError(
            statusCode: 500,
            logMessage: "Internal Server Error"
        )

        let viewModel = makeViewModel(recipeEngine: mockEngine)

        await viewModel.generateRecipes(
            ingredients: sampleIngredients,
            cuisine: sampleCuisine,
            dietaryPreference: sampleDietaryPreference,
            skillLevel: sampleSkillLevel
        )

        guard case .error(let error) = viewModel.state else {
            XCTFail("State should be .error after a server error, got \(viewModel.state)")
            return
        }

        guard case .serverError(let statusCode, _) = error else {
            XCTFail("Error should be .serverError, got \(error)")
            return
        }

        XCTAssertEqual(statusCode, 500,
                       "serverError statusCode should be 500")
    }

    // MARK: - No Results Found Error

    /// When the service throws `RecipeEngineError.noResultsFound`, `state`
    /// SHALL transition to `.error(.noResultsFound)`.
    func testNoResultsFoundErrorTransitionsToErrorNoResultsFound() async {
        let mockEngine = MockRecipeEngineService()
        mockEngine.errorToThrow = RecipeEngineError.noResultsFound

        let viewModel = makeViewModel(recipeEngine: mockEngine)

        await viewModel.generateRecipes(
            ingredients: sampleIngredients,
            cuisine: sampleCuisine,
            dietaryPreference: sampleDietaryPreference,
            skillLevel: sampleSkillLevel
        )

        guard case .error(let error) = viewModel.state else {
            XCTFail("State should be .error after no results found, got \(viewModel.state)")
            return
        }

        guard case .noResultsFound = error else {
            XCTFail("Error should be .noResultsFound, got \(error)")
            return
        }
    }

    // MARK: - Non-RecipeEngineError Fallback

    /// When the service throws a non-`RecipeEngineError`, `state` SHALL
    /// transition to `.error(.invalidResponse)`.
    func testUnknownErrorTransitionsToErrorInvalidResponse() async {
        let mockEngine = MockRecipeEngineService()
        mockEngine.errorToThrow = NSError(domain: "UnknownError", code: 42, userInfo: nil)

        let viewModel = makeViewModel(recipeEngine: mockEngine)

        await viewModel.generateRecipes(
            ingredients: sampleIngredients,
            cuisine: sampleCuisine,
            dietaryPreference: sampleDietaryPreference,
            skillLevel: sampleSkillLevel
        )

        guard case .error(let error) = viewModel.state else {
            XCTFail("State should be .error for an unknown error, got \(viewModel.state)")
            return
        }

        guard case .invalidResponse = error else {
            XCTFail("Error should be .invalidResponse for an unknown error, got \(error)")
            return
        }
    }

    // MARK: - Preference Persistence After Successful Generation (Requirement 8.1)

    /// After a successful generation, `generateRecipes` SHALL call
    /// `PreferencePersistenceService.savePreferences` with the used preferences.
    ///
    /// Validates: Requirement 8.1
    func testSuccessfulGenerationSavesPreferences() async {
        let mockEngine = MockRecipeEngineService()
        mockEngine.recipesToReturn = [makeSampleRankedRecipe()]

        let mockPersistence = MockPreferencePersistenceService()

        let viewModel = makeViewModel(
            recipeEngine: mockEngine,
            persistence: mockPersistence
        )

        await viewModel.generateRecipes(
            ingredients: sampleIngredients,
            cuisine: .northIndian,
            dietaryPreference: .vegetarian,
            skillLevel: .beginner
        )

        XCTAssertEqual(mockPersistence.savedProfiles.count, 1,
                       "Preferences should be saved exactly once after a successful generation")

        let saved = mockPersistence.savedProfiles.first
        XCTAssertEqual(saved?.cuisine, Cuisine.northIndian.rawValue,
                       "Saved profile should contain the selected cuisine")
        XCTAssertEqual(saved?.dietaryPreference, DietaryPreference.vegetarian.rawValue,
                       "Saved profile should contain the selected dietary preference")
        XCTAssertEqual(saved?.skillLevel, SkillLevel.beginner.rawValue,
                       "Saved profile should contain the selected skill level")
    }

    /// After a failed generation, `generateRecipes` SHALL NOT call
    /// `PreferencePersistenceService.savePreferences`.
    ///
    /// Validates: Requirement 8.1
    func testFailedGenerationDoesNotSavePreferences() async {
        let mockEngine = MockRecipeEngineService()
        mockEngine.errorToThrow = RecipeEngineError.timeout

        let mockPersistence = MockPreferencePersistenceService()

        let viewModel = makeViewModel(
            recipeEngine: mockEngine,
            persistence: mockPersistence
        )

        await viewModel.generateRecipes(
            ingredients: sampleIngredients,
            cuisine: sampleCuisine,
            dietaryPreference: sampleDietaryPreference,
            skillLevel: sampleSkillLevel
        )

        XCTAssertTrue(mockPersistence.savedProfiles.isEmpty,
                      "Preferences should NOT be saved when generation fails")
    }

    /// `generateRecipes` SHALL silently ignore errors thrown by
    /// `PreferencePersistenceService.savePreferences` and still set state
    /// to `.results`.
    ///
    /// Validates: Requirement 8.1
    func testPersistenceErrorDoesNotAffectResultsState() async {
        let mockEngine = MockRecipeEngineService()
        mockEngine.recipesToReturn = [makeSampleRankedRecipe()]

        let mockPersistence = MockPreferencePersistenceService()
        mockPersistence.shouldThrowOnSave = true

        let viewModel = makeViewModel(
            recipeEngine: mockEngine,
            persistence: mockPersistence
        )

        await viewModel.generateRecipes(
            ingredients: sampleIngredients,
            cuisine: sampleCuisine,
            dietaryPreference: sampleDietaryPreference,
            skillLevel: sampleSkillLevel
        )

        // State should still be .results despite the persistence error.
        guard case .results = viewModel.state else {
            XCTFail("State should be .results even when preference persistence fails")
            return
        }
    }

    // MARK: - Pantry Staples Fetched for Selected Cuisine

    /// `generateRecipes` SHALL fetch pantry staples for the selected cuisine
    /// via `PantryStaplesService` before building the generation request.
    ///
    /// Validates: Requirement 4.1
    func testPantryStaplesAreFetchedForSelectedCuisine() async {
        let mockPantry = MockPantryStaplesService()
        mockPantry.staplesToReturn = ["Salt", "Oil", "Turmeric"]

        let capturingEngine = CapturingRecipeEngineService(
            recipesToReturn: [makeSampleRankedRecipe()]
        )

        let viewModel = makeViewModel(
            recipeEngine: capturingEngine,
            pantryStaples: mockPantry
        )

        await viewModel.generateRecipes(
            ingredients: sampleIngredients,
            cuisine: .northIndian,
            dietaryPreference: nil,
            skillLevel: .beginner
        )

        XCTAssertNotNil(capturingEngine.capturedRequest,
                        "The recipe engine should have been called with a request")
        XCTAssertEqual(capturingEngine.capturedRequest?.pantryStaples, ["Salt", "Oil", "Turmeric"],
                       "The request should include the pantry staples from the mock service")
        XCTAssertEqual(capturingEngine.capturedRequest?.cuisine, .northIndian,
                       "The request should include the selected cuisine")
    }
}

// MARK: - CapturingRecipeEngineService

/// A test double that captures the `RecipeGenerationRequest` passed to it,
/// enabling tests to verify the request was constructed correctly.
private final class CapturingRecipeEngineService: RecipeEngineServiceProtocol {

    private let recipesToReturn: [RankedRecipe]
    private(set) var capturedRequest: RecipeGenerationRequest?

    init(recipesToReturn: [RankedRecipe]) {
        self.recipesToReturn = recipesToReturn
    }

    @MainActor
    func generateRecipes(request: RecipeGenerationRequest) async throws -> [RankedRecipe] {
        capturedRequest = request
        return recipesToReturn
    }
}
