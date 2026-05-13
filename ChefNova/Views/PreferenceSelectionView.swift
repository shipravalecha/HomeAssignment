// PreferenceSelectionView.swift
// ChefNova
//
// View for selecting cuisine, dietary preference, and skill level before
// recipe generation.
//
// Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.5, 3.6

import SwiftUI

/// The second screen in the recipe generation flow.
///
/// Lets the user choose a cuisine (required), an optional dietary preference,
/// and a skill level, then navigates to the recipe results screen.
struct PreferenceSelectionView: View {

    @State var viewModel: PreferenceViewModel
    /// The canonical ingredient names collected on the previous screen.
    let ingredients: [CanonicalIngredient]
    /// Factory closure that produces a `RecipeResultsViewModel` for the next screen.
    var makeResultsViewModel: () -> RecipeResultsViewModel

    @State private var navigateToResults = false

    // MARK: - Init

    /// Convenience initialiser used when navigating from `IngredientInputView`.
    /// The `makeResultsViewModel` factory defaults to creating a fully wired
    /// production view model.
    init(
        viewModel: PreferenceViewModel,
        ingredients: [CanonicalIngredient],
        makeResultsViewModel: @escaping () -> RecipeResultsViewModel = {
            RecipeResultsViewModel(
                recipeEngineService: RecipeEngineService(),
                pantryStaplesService: PantryStaplesService(),
                persistenceService: NoOpPreferencePersistenceService()
            )
        }
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.ingredients = ingredients
        self.makeResultsViewModel = makeResultsViewModel
    }

    // MARK: - Body

    var body: some View {
        Form {
            // MARK: Cuisine picker (required)
            Section {
                Picker("Cuisine", selection: $viewModel.selectedCuisine) {
                    ForEach(Cuisine.allCases, id: \.self) { cuisine in
                        Text(cuisine.rawValue).tag(Optional(cuisine))
                    }
                }
                .accessibilityIdentifier("cuisinePicker")
            }

            // MARK: Dietary preference picker (optional)
            Section {
                Picker("Dietary Preference", selection: $viewModel.selectedDietaryPreference) {
                    Text("No Preference").tag(Optional<DietaryPreference>.none)
                    ForEach(DietaryPreference.allCases, id: \.self) { pref in
                        Text(pref.rawValue).tag(Optional(pref))
                    }
                }
                .accessibilityIdentifier("dietaryPreferencePicker")
            }

            // MARK: Skill level picker
            Section {
                Picker("Skill Level", selection: $viewModel.selectedSkillLevel) {
                    ForEach(SkillLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .accessibilityIdentifier("skillLevelPicker")
            }

            // MARK: Validation error
            if let error = viewModel.validationError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .accessibilityIdentifier("preferenceValidationErrorText")
                }
            }

            // MARK: Generate button
            Section {
                Button {
                    if viewModel.validateForSubmission() {
                        navigateToResults = true
                    }
                } label: {
                    Text("Find Recipes")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("findRecipesButton")
            }
        }
        .navigationTitle("Preferences")
        .navigationDestination(isPresented: $navigateToResults) {
            if let cuisine = viewModel.selectedCuisine {
                RecipeResultsView(
                    viewModel: makeResultsViewModel(),
                    ingredients: ingredients,
                    cuisine: cuisine,
                    dietaryPreference: viewModel.selectedDietaryPreference,
                    skillLevel: viewModel.selectedSkillLevel
                )
            }
        }
    }
}

// MARK: - NoOpPreferencePersistenceService

/// A no-op persistence service used when a real `ModelContext` is not
/// available at view construction time. The `RecipeResultsViewModel` handles
/// its own persistence internally after a successful generation.
private final class NoOpPreferencePersistenceService: PreferencePersistenceServiceProtocol {
    func savePreferences(_ profile: PreferenceProfile) throws {}
    func loadLatestPreferences() -> PreferenceProfile? { nil }
}
