// RecipeResultsViewModel.swift
// ChefNova
//
// Orchestrates recipe generation by coordinating the RecipeEngineService,
// PantryStaplesService, and PreferencePersistenceService. Also monitors
// network reachability via NWPathMonitor.
//
// Requirements: 4.1, 4.2, 4.3, 4.5, 8.1, 9.3

import Foundation
import Network
import Observation

/// View model for the Recipe Results screen.
///
/// Drives the full recipe generation pipeline: fetches pantry staples,
/// builds the generation request, calls the recipe engine, and persists
/// the user's preferences on success. Network availability is tracked
/// continuously via `NWPathMonitor`.
@MainActor
@Observable
final class RecipeResultsViewModel {

    // MARK: - Nested Types

    /// Represents the current state of the recipe generation pipeline.
    enum LoadingState {
        case idle
        case loading
        case results([RankedRecipe])
        case error(RecipeEngineError)
    }

    // MARK: - State

    /// The current loading state of the recipe generation pipeline.
    var state: LoadingState = .idle

    /// Whether a network path is currently available.
    /// Updated continuously by `NWPathMonitor` on a background queue.
    var isNetworkAvailable: Bool = true

    // MARK: - Dependencies

    private let recipeEngineService: RecipeEngineServiceProtocol
    private let pantryStaplesService: PantryStaplesServiceProtocol
    private let persistenceService: PreferencePersistenceServiceProtocol

    // MARK: - Network Monitor

    private let pathMonitor: NWPathMonitor
    private let monitorQueue: DispatchQueue

    // MARK: - Init

    /// Creates the view model with the given service dependencies.
    ///
    /// Immediately starts an `NWPathMonitor` on a background queue to track
    /// network reachability.
    ///
    /// - Parameters:
    ///   - recipeEngineService: The service used to generate ranked recipes.
    ///   - pantryStaplesService: The service used to fetch cuisine-specific pantry staples.
    ///   - persistenceService: The service used to persist the user's preference profile.
    init(
        recipeEngineService: RecipeEngineServiceProtocol,
        pantryStaplesService: PantryStaplesServiceProtocol,
        persistenceService: PreferencePersistenceServiceProtocol
    ) {
        self.recipeEngineService = recipeEngineService
        self.pantryStaplesService = pantryStaplesService
        self.persistenceService = persistenceService

        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "com.chefnova.networkMonitor", qos: .utility)
        self.pathMonitor = monitor
        self.monitorQueue = queue

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isNetworkAvailable = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    // MARK: - Deinit

    deinit {
        pathMonitor.cancel()
    }

    // MARK: - Methods

    /// Generates recipes for the given inputs.
    ///
    /// The pipeline:
    /// 1. Sets state to `.loading`.
    /// 2. Fetches pantry staples for the selected cuisine.
    /// 3. Builds a `RecipeGenerationRequest`.
    /// 4. Calls the recipe engine service.
    /// 5. On success, sets state to `.results` and persists the user's preferences.
    /// 6. On `RecipeEngineError`, sets state to `.error(error)`.
    /// 7. On any other error, sets state to `.error(.invalidResponse)`.
    ///
    /// - Parameters:
    ///   - ingredients: The canonical ingredient names provided by the user.
    ///   - cuisine: The cuisine selected by the user.
    ///   - dietaryPreference: The optional dietary preference filter.
    ///   - skillLevel: The cooking skill level filter.
    func generateRecipes(
        ingredients: [String],
        cuisine: Cuisine,
        dietaryPreference: DietaryPreference?,
        skillLevel: SkillLevel
    ) async {
        state = .loading

        do {
            // Fetch pantry staples for the selected cuisine.
            let pantryStaples = pantryStaplesService.getPantryStaples(for: cuisine)

            // Build the generation request.
            let request = RecipeGenerationRequest(
                ingredients: ingredients,
                pantryStaples: pantryStaples,
                cuisine: cuisine,
                dietaryPreference: dietaryPreference,
                skillLevel: skillLevel
            )

            // Call the recipe engine.
            let rankedRecipes = try await recipeEngineService.generateRecipes(request: request)

            // Update state with results.
            state = .results(rankedRecipes)

            // Persist the user's preferences (errors are silently ignored).
            let profile = PreferenceProfile(
                cuisine: cuisine.rawValue,
                dietaryPreference: dietaryPreference?.rawValue,
                skillLevel: skillLevel.rawValue
            )
            try? persistenceService.savePreferences(profile)

        } catch let engineError as RecipeEngineError {
            state = .error(engineError)
        } catch {
            state = .error(.invalidResponse)
        }
    }
}
