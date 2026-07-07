// ChefNovaApp.swift
// ChefNova
//
// App entry point. Configures the SwiftData ModelContainer, instantiates all
// services once at the app level, and wires them into the view hierarchy via
// factory closures.
//
// Requirements: 8.3, 4.1, 6.1

import SwiftUI
import SwiftData

@main
struct ChefNovaApp: App {

    // MARK: - SwiftData container

    /// The shared SwiftData container for `PreferenceProfile` and `FavouriteRecipe`.
    /// Created once with `try!` — a misconfigured schema is a programmer error
    /// that should surface immediately during development (MVP).
    let container: ModelContainer = {
        // swiftlint:disable:next force_try
        try! ModelContainer(for: PreferenceProfile.self, FavouriteRecipe.self)
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(container)
    }
}

// MARK: - AppRootView

/// A thin root view that reads the SwiftData `ModelContext` from the
/// environment, instantiates all app-level services exactly once, and
/// presents `IngredientInputView` with fully wired factory closures.
///
/// Using a separate `View` (rather than putting service creation directly in
/// `ChefNovaApp.body`) lets us access `@Environment(\.modelContext)` cleanly
/// and keeps service lifetimes tied to the window's lifetime.
struct AppRootView: View {

    // MARK: - SwiftData context

    @Environment(\.modelContext) private var modelContext

    // MARK: - Services (created once, stored as @State to survive re-renders)

    /// Normalises raw ingredient names to canonical forms using SynonymDictionary.json.
    @State private var normalizerService = IngredientNormalizerService()

    /// Provides cuisine-specific pantry staples from PantryStaples.json.
    @State private var pantryStaplesService = PantryStaplesService()

    /// Calls the OpenAI Chat Completions API to generate ranked recipes.
    /// Uses its default init which reads the API key from Info.plist.
    @State private var recipeEngineService = RecipeEngineService()

    // MARK: - Body

    var body: some View {
        // Build the persistence service here so it captures the live modelContext.
        let persistenceService = PreferencePersistenceService(context: modelContext)
        let favouritesService = FavouritesService(context: modelContext)

        // When launched with "--uitesting", inject a mock RecipeEngineService
        // so UI tests receive deterministic, pre-canned recipe data without
        // making real network calls.
        //
        // When launched with "--uitesting-network-error", inject a mock that
        // throws RecipeEngineError.networkUnavailable so the error banner UI
        // can be exercised in UI tests.
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")
        let isNetworkErrorTesting = ProcessInfo.processInfo.arguments.contains("--uitesting-network-error")

        WelcomeView {
            IngredientInputView(
                viewModel: IngredientInputViewModel(normalizer: normalizerService),
                makePreferenceViewModel: {
                    PreferenceViewModel(persistenceService: persistenceService)
                },
                makeResultsViewModel: (isUITesting || isNetworkErrorTesting)
                    ? makeUITestingResultsViewModel(
                        persistenceService: persistenceService,
                        shouldThrowNetworkError: isNetworkErrorTesting
                      )
                    : nil
            )
        }
        .environment(\.favouritesService, favouritesService)
    }

    // MARK: - Helpers

    /// Returns a factory closure that creates a `RecipeResultsViewModel` wired
    /// with a `MockRecipeEngineService` for UI testing.
    ///
    /// Separated into its own method so the `#if DEBUG` conditional compiles
    /// cleanly outside of a `@ViewBuilder` context.
    ///
    /// - Parameters:
    ///   - persistenceService: The persistence service to inject.
    ///   - shouldThrowNetworkError: When `true`, the mock throws
    ///     `RecipeEngineError.networkUnavailable` to exercise the error banner.
    private func makeUITestingResultsViewModel(
        persistenceService: PreferencePersistenceServiceProtocol,
        shouldThrowNetworkError: Bool = false
    ) -> () -> RecipeResultsViewModel {
        return {
            #if DEBUG
            RecipeResultsViewModel(
                recipeEngineService: MockRecipeEngineService(shouldThrowNetworkError: shouldThrowNetworkError),
                pantryStaplesService: PantryStaplesService(),
                persistenceService: persistenceService
            )
            #else
            RecipeResultsViewModel(
                recipeEngineService: RecipeEngineService(),
                pantryStaplesService: PantryStaplesService(),
                persistenceService: persistenceService
            )
            #endif
        }
    }
}
