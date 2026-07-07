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
/// Triggers recipe generation on appear, shows a shimmer skeleton while
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
                Color.clear

            case .loading:
                loadingSkeletonView

            case .results(let rankedRecipes):
                resultsList(rankedRecipes)

            case .error(let error):
                errorBanner(error)
            }
        }
        .navigationTitle("Recipes")
        .task {
            guard case .idle = viewModel.state else { return }
            await viewModel.generateRecipes(
                ingredients: ingredients,
                cuisine: cuisine,
                dietaryPreference: dietaryPreference,
                skillLevel: skillLevel
            )
        }
    }

    // MARK: - Shimmer skeleton

    private var loadingSkeletonView: some View {
        List {
            // Hint label matching the real results list
            Section {
                Label(
                    "Common pantry staples (salt, oil, spices, etc.) are assumed available.",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // Three placeholder recipe card skeletons
            ForEach(0..<3, id: \.self) { index in
                SkeletonRecipeCard()
                    // Stagger the animation start so cards don't all pulse in sync
                    .id(index)
            }
        }
        .listStyle(.insetGrouped)
        .allowsHitTesting(false) // Prevent tapping skeleton cards
    }

    // MARK: - Results list

    @ViewBuilder
    private func resultsList(_ rankedRecipes: [RankedRecipe]) -> some View {
        List {
            Section {
                Label(
                    "Common pantry staples (salt, oil, spices, etc.) are assumed available.",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

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

            HStack(spacing: 12) {
                Label("\(ranked.recipe.prepTimeMinutes + ranked.recipe.cookTimeMinutes) min", systemImage: "clock")
                    .accessibilityIdentifier("recipeCardTime")
                Label("Serves \(ranked.recipe.servingSize)", systemImage: "person.2")
                Label(ranked.recipe.skillLevel.rawValue, systemImage: "chart.bar")
                    .accessibilityIdentifier("recipeCardSkillLevel")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

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

// MARK: - Shimmer modifier

/// Applies a left-to-right shimmer highlight effect to any view.
private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.45), location: 0.4),
                            .init(color: .white.opacity(0.45), location: 0.6),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: geo.size.width * phase)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.4)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1.5
                }
            }
    }
}

private extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton recipe card

/// A placeholder card that mimics the shape of a real recipe card while loading.
private struct SkeletonRecipeCard: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title bar placeholder
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 180, height: 16)
                    .shimmer()
                Spacer()
                // Match score pill placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 16)
                    .shimmer()
            }

            // Metadata row placeholder
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 12)
                    .shimmer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 12)
                    .shimmer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 12)
                    .shimmer()
            }
        }
        .padding(.vertical, 8)
    }
}
