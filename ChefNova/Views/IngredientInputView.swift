// IngredientInputView.swift
// ChefNova
//
// View for entering and managing the ingredient list before recipe generation.
//
// Requirements: 1.1, 1.2, 1.4, 1.5, 1.6, 1.7

import SwiftUI

/// The first screen in the recipe generation flow.
///
/// Allows the user to type ingredient names, add them to a validated list,
/// remove them via swipe-to-delete, and navigate to preference selection
/// once the list is non-empty.
struct IngredientInputView: View {

    @State private var viewModel: IngredientInputViewModel
    let makePreferenceViewModel: () -> PreferenceViewModel
    /// Optional override for the `RecipeResultsViewModel` factory, forwarded
    /// to `PreferenceSelectionView`. When `nil`, `PreferenceSelectionView`
    /// uses its own default factory (production `RecipeEngineService`).
    let makeResultsViewModel: (() -> RecipeResultsViewModel)?

    @State private var navigateToPreferences = false
    @State private var showScanner = false
    @State private var showFavourites = false
    /// Keeps the text field focused so the cursor returns after each add.
    @FocusState private var isTextFieldFocused: Bool

    // MARK: - Init

    init(
        viewModel: IngredientInputViewModel,
        makePreferenceViewModel: @escaping () -> PreferenceViewModel,
        makeResultsViewModel: (() -> RecipeResultsViewModel)? = nil
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.makePreferenceViewModel = makePreferenceViewModel
        self.makeResultsViewModel = makeResultsViewModel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: Input row
                HStack {
                    TextField("Enter an ingredient", text: $viewModel.rawInput)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .focused($isTextFieldFocused)
                        .accessibilityIdentifier("ingredientTextField")
                        .onSubmit {
                            addIngredient()
                        }

                    // Scan barcode button
                    Button {
                        isTextFieldFocused = false
                        showScanner = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .accessibilityLabel("Scan barcode")
                    .accessibilityIdentifier("scanBarcodeButton")

                    Button("Add") {
                        addIngredient()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.rawInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("addIngredientButton")
                }
                .padding()

                // MARK: Barcode lookup status
                if viewModel.isLookingUpBarcode {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Looking up product…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }

                if let barcodeError = viewModel.barcodeError {
                    Text(barcodeError)
                        .foregroundStyle(.orange)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }

                // MARK: Validation error
                if let error = viewModel.validationError {
                    Text(validationMessage(for: error))
                        .foregroundStyle(.red)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                        .accessibilityIdentifier("validationErrorText")
                }

                // MARK: Ingredient list with swipe-to-delete
                List {
                    ForEach(viewModel.ingredients, id: \.self) { ingredient in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text(ingredient)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet.sorted().reversed() {
                            viewModel.removeIngredient(at: index)
                        }
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if viewModel.ingredients.isEmpty {
                        ContentUnavailableView(
                            "No ingredients yet",
                            systemImage: "cart",
                            description: Text("Type an ingredient above and tap Add.")
                        )
                    }
                }

                // MARK: Generate button
                Button {
                    if viewModel.validateForSubmission() {
                        navigateToPreferences = true
                    }
                } label: {
                    Text("Generate Recipes")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .accessibilityIdentifier("generateRecipesButton")
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isTextFieldFocused = false
            }
            .navigationTitle("Ingredients")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !viewModel.ingredients.isEmpty {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Favourites") {
                        showFavourites = true
                    }
                    .accessibilityIdentifier("favouritesButton")
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
            .sheet(isPresented: $showScanner) {
                NavigationStack {
                    BarcodeScannerView { barcode in
                        viewModel.addIngredientFromBarcode(barcode)
                    }
                    .navigationTitle("Scan Barcode")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .navigationDestination(isPresented: $showFavourites) {
                FavouritesView()
            }
            .navigationDestination(isPresented: $navigateToPreferences) {
                if let makeResultsVM = makeResultsViewModel {
                    PreferenceSelectionView(
                        viewModel: makePreferenceViewModel(),
                        ingredients: viewModel.ingredients,
                        makeResultsViewModel: makeResultsVM
                    )
                } else {
                    PreferenceSelectionView(
                        viewModel: makePreferenceViewModel(),
                        ingredients: viewModel.ingredients
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func addIngredient() {
        viewModel.addIngredient()
        // Re-focus the text field so the user can immediately type the next ingredient.
        isTextFieldFocused = true
    }

    private func validationMessage(for error: IngredientValidationError) -> String {
        switch error {
        case .unrecognized(let rawName):
            return "We didn't recognize '\(rawName)'. Please check the spelling."
        case .emptyList, .allWhitespace:
            return "Please add at least one ingredient before generating recipes."
        }
    }
}
