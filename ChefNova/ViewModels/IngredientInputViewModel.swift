// IngredientInputViewModel.swift
// ChefNova
//
// ViewModel for the Ingredient Input screen. Manages the list of validated
// ingredients, raw text input, and validation error state.
//
// Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7

import Foundation
import Observation

@MainActor
@Observable
final class IngredientInputViewModel {

    // MARK: - State

    var ingredients: [CanonicalIngredient] = []
    var rawInput: String = ""
    var validationError: IngredientValidationError?
    var isLookingUpBarcode: Bool = false
    var barcodeError: String?

    /// Set to the duplicate canonical name when the user tries to add an
    /// ingredient that is already in the list. The view observes this to
    /// show a confirmation alert.
    var duplicateIngredient: CanonicalIngredient? = nil

    // MARK: - Dependencies

    private let normalizer: IngredientNormalizerServiceProtocol
    private let barcodeLookup: BarcodeProductLookupServiceProtocol

    // MARK: - Init

    init(
        normalizer: IngredientNormalizerServiceProtocol,
        barcodeLookup: BarcodeProductLookupServiceProtocol = BarcodeProductLookupService()
    ) {
        self.normalizer = normalizer
        self.barcodeLookup = barcodeLookup
    }

    // MARK: - Methods

    /// Attempts to add the current `rawInput` as a validated ingredient.
    /// If the ingredient is already in the list, sets `duplicateIngredient`
    /// so the view can prompt the user. If unrecognised, sets `validationError`.
    func addIngredient() {
        guard let canonical = normalizer.normalize(rawInput) else {
            validationError = .unrecognized(rawName: rawInput)
            return
        }
        if ingredients.contains(canonical) {
            // Signal the view to show a duplicate confirmation alert.
            duplicateIngredient = canonical
        } else {
            ingredients.append(canonical)
            rawInput = ""
            validationError = nil
        }
    }

    /// Force-adds the duplicate ingredient (called when user confirms the alert).
    func forceAddDuplicate() {
        guard let canonical = duplicateIngredient else { return }
        ingredients.append(canonical)
        rawInput = ""
        validationError = nil
        duplicateIngredient = nil
    }

    /// Dismisses the duplicate alert without adding.
    func cancelDuplicate() {
        duplicateIngredient = nil
    }

    func removeIngredient(at index: Int) {
        ingredients.remove(at: index)
    }

    @discardableResult
    func validateForSubmission() -> Bool {
        if ingredients.isEmpty {
            validationError = .emptyList
            return false
        }
        validationError = nil
        return true
    }

    // MARK: - Barcode scanning

    func addIngredientFromBarcode(_ barcode: String) {
        barcodeError = nil
        isLookingUpBarcode = true

        Task {
            defer { isLookingUpBarcode = false }

            guard let productName = await barcodeLookup.lookupIngredientName(for: barcode) else {
                barcodeError = "Product not found for this barcode. Try typing the ingredient instead."
                return
            }

            if let canonical = normalizer.normalize(productName) {
                if !ingredients.contains(canonical) {
                    ingredients.append(canonical)
                }
                barcodeError = nil
            } else {
                rawInput = productName
                barcodeError = "Found '\(productName)' — not in our ingredient list. You can edit and add it manually."
            }
        }
    }
}
