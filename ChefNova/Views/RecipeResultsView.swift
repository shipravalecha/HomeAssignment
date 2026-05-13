// RecipeResultsView.swift
// ChefNova
//
// View that displays the recipe generation results, including loading state,
// error handling, and a list of ranked recipe cards.
//
// Requirements: 4.4, 4.5, 4.6, 5.1, 5.2, 5.3, 5.4, 9.2, 9.3, 9.4, 10.5

import SwiftUI

/// The third screen in the recipe generation flow.
///
/// Triggers recipe generation on appear, shows a progress indicator while
/// loading, displays ranked recipe cards on success, and shows an error
/// banner with retry on failure.
struct RecipeResultsView: View {

    @State private var viewModel: RecipeResultsViewModel

    let ingredients: [CanonicalIngredient]
    let cuisine: Cuisine
    let dietaryPreference: DietaryPreference?
    let skillLevel: SkillLevel

    // MARK: - Init

    init(
        viewModel: RecipeResultsViewModel,
        ingredients: [CanonicalIngredient],
        cuisine: Cuisine,
        dietaryPreference: DietaryPreference?,
        skillLevel: SkillLevel
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.ingredients = ingredients
        self.cuisine = cuisine
        self.dietaryPreference = dietaryPreference
        self.skillLevel = skillLevel
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                // Briefly shown before .task fires; show nothing meaningful.
                Color.clear

            case .loading:
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Finding recipes…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .results(let rankedRecipes):
                resultsList(rankedRecipes)

            case .error(let error):
                errorBanner(error)
            }
        }
        .navigationTitle("Recipes")
        .task {
            // Only generate if we haven't already — prevents re-triggering
            // when navigating back from RecipeDetailView.
            guard case .idle = viewModel.state else { return }
            await viewModel.generateRecipes(
                ingredients: ingredients,
                cuisine: cuisine,
                dietaryPreference: dietaryPreference,
                skillLevel: skillLevel
            )
        }
    }

    // MARK: - Results list

    @ViewBuilder
    private func resultsList(_ rankedRecipes: [RankedRecipe]) -> some View {
        List {
            // Pantry staples notice
            Section {
                Label(
                    "Common pantry staples (salt, oil, spices, etc.) are assumed available.",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // Recipe cards
            ForEach(rankedRecipes) { ranked in
                NavigationLink(destination: RecipeDetailView(viewModel: RecipeDetailViewModel(rankedRecipe: ranked))) {
                    recipeCard(ranked)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Recipe card

    @ViewBuilder
    private func recipeCard(_ ranked: RankedRecipe) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title and match score
            HStack {
                Text(ranked.recipe.title)
                    .font(.headline)
                    .accessibilityIdentifier("recipeCardTitle")
                Spacer()
                Text(matchScoreText(ranked.matchScore))
                    .font(.subheadline)
                    .foregroundStyle(ranked.isPartialMatch ? .orange : .green)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("recipeCardMatchScore")
            }

            // Metadata row
            HStack(spacing: 12) {
                Label("\(ranked.recipe.prepTimeMinutes + ranked.recipe.cookTimeMinutes) min", systemImage: "clock")
                    .accessibilityIdentifier("recipeCardTime")
                Label("Serves \(ranked.recipe.servingSize)", systemImage: "person.2")
                Label(ranked.recipe.skillLevel.rawValue, systemImage: "chart.bar")
                    .accessibilityIdentifier("recipeCardSkillLevel")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Gap ingredients for partial matches
            if ranked.isPartialMatch && !ranked.gapIngredients.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Missing ingredients:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(ranked.gapIngredients, id: \.name) { gap in
                        Link(gap.name, destination: gap.purchaseSearchURL)
                            .font(.caption)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("recipeCard_\(ranked.recipe.title.replacingOccurrences(of: " ", with: "_"))")
    }

    // MARK: - Error banner

    @ViewBuilder
    private func errorBanner(_ error: RecipeEngineError) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text(error.errorDescription ?? "An unexpected error occurred.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .accessibilityIdentifier("errorBannerText")

            if case .noResultsFound = error {
                // No retry for no-results — just show the message.
                EmptyView()
            } else {
                Button("Retry") {
                    Task {
                        await viewModel.generateRecipes(
                            ingredients: ingredients,
                            cuisine: cuisine,
                            dietaryPreference: dietaryPreference,
                            skillLevel: skillLevel
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.isNetworkAvailable)
                .accessibilityIdentifier("retryButton")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("errorBanner")
    }

    // MARK: - Helpers

    private func matchScoreText(_ score: Double) -> String {
        let percentage = Int((score * 100).rounded())
        return "\(percentage)%"
    }
}
