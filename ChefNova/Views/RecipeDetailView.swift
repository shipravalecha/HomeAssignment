// RecipeDetailView.swift
// ChefNova
//
// View that displays the full details of a selected recipe, including
// serving-size adjustment, scaled ingredients, and cooking steps.
//
// Requirements: 6.1, 6.2, 6.3, 6.4

import SwiftUI

/// The fourth screen in the recipe generation flow.
///
/// Shows recipe metadata, a stepper to adjust serving size, scaled ingredient
/// quantities, numbered cooking steps, and a gap-ingredients section for
/// partial matches.
struct RecipeDetailView: View {

    @State private var viewModel: RecipeDetailViewModel

    // MARK: - Init

    init(viewModel: RecipeDetailViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        List {
            // MARK: Metadata section
            Section("About") {
                metadataRow(label: "Cuisine", value: viewModel.rankedRecipe.recipe.cuisine.rawValue)
                metadataRow(label: "Dietary", value: viewModel.rankedRecipe.recipe.dietaryClassification.rawValue)
                metadataRow(label: "Skill Level", value: viewModel.rankedRecipe.recipe.skillLevel.rawValue)
                metadataRow(
                    label: "Total Time",
                    value: "\(viewModel.rankedRecipe.recipe.prepTimeMinutes + viewModel.rankedRecipe.recipe.cookTimeMinutes) min"
                )
                metadataRow(label: "Original Servings", value: "\(viewModel.rankedRecipe.recipe.servingSize)")
            }

            // MARK: Serving size stepper
            Section("Servings") {
                Stepper(
                    "Servings: \(viewModel.targetServings)",
                    value: $viewModel.targetServings,
                    in: 1...99
                )
                .accessibilityIdentifier("servingsStepper")
            }

            // MARK: Ingredients section
            Section("Ingredients") {
                ForEach(viewModel.adjustedIngredients, id: \.name) { ingredient in
                    HStack {
                        Text(ingredient.name)
                            .accessibilityIdentifier("ingredientName_\(ingredient.name.replacingOccurrences(of: " ", with: "_"))")
                        Spacer()
                        Text("\(formattedQuantity(ingredient.quantity)) \(ingredient.unit)")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("ingredientQuantity_\(ingredient.name.replacingOccurrences(of: " ", with: "_"))")
                    }
                    .accessibilityIdentifier("ingredientRow_\(ingredient.name.replacingOccurrences(of: " ", with: "_"))")
                }
            }

            // MARK: Steps section
            Section("Steps") {
                ForEach(Array(viewModel.rankedRecipe.recipe.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1).")
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 24, alignment: .trailing)
                        Text(step)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            }

            // MARK: Gap ingredients section (partial matches only)
            if viewModel.rankedRecipe.isPartialMatch && !viewModel.rankedRecipe.gapIngredients.isEmpty {
                Section {
                    ForEach(viewModel.rankedRecipe.gapIngredients, id: \.name) { gap in
                        HStack {
                            Image(systemName: "cart.badge.plus")
                                .foregroundStyle(.orange)
                            Link(gap.name, destination: gap.purchaseSearchURL)
                        }
                    }
                } header: {
                    Label("Missing Ingredients", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } footer: {
                    Text("Tap an ingredient to find it online.")
                        .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(viewModel.rankedRecipe.recipe.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }

    /// Formats a quantity to at most 2 decimal places, stripping trailing zeros.
    ///
    /// Examples: 1.0 → "1", 0.5 → "0.5", 1.25 → "1.25"
    private func formattedQuantity(_ quantity: Double) -> String {
        // Use up to 2 decimal places, removing trailing zeros.
        let formatted = String(format: "%.2f", quantity)
        // Strip trailing zeros after the decimal point.
        if formatted.contains(".") {
            var result = formatted
            while result.hasSuffix("0") {
                result.removeLast()
            }
            if result.hasSuffix(".") {
                result.removeLast()
            }
            return result
        }
        return formatted
    }
}
