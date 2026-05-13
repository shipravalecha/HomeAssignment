// IngredientInputViewModel.swift
// ChefNova
//
// ViewModel for the Ingredient Input screen. Manages the list of validated
// ingredients, raw text input, and validation error state.
//
// Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7

import Foundation
import Observation

/// View model for the ingredient input screen.
///
/// Handles normalisation of raw user input via `IngredientNormalizerServiceProtocol`,
/// maintains the validated ingredient list, and exposes validation errors for
/// display in the UI.
@MainActor
@Observable
final class IngredientInputViewModel {

    // MARK: - State

    /// The list of validated, canonical ingredient names.
    var ingredients: [CanonicalIngredient] = []

    /// The current text field content entered by the user.
    var rawInput: String = ""

    /// The current validation error, if any. `nil` when there is no error.
    var validationError: IngredientValidationError?

    /// `true` while a barcode lookup network request is in flight.
    var isLookingUpBarcode: Bool = false

    /// Non-nil when a barcode was scanned but could not be resolved or normalised.
    var barcodeError: String?

    // MARK: - Dependencies

    private let normalizer: IngredientNormalizerServiceProtocol
    private let barcodeLookup: BarcodeProductLookupServiceProtocol

    // MARK: - Init

    /// Creates the view model with the given normaliser and barcode lookup services.
    ///
    /// - Parameters:
    ///   - normalizer: Maps raw ingredient names to canonical forms.
    ///   - barcodeLookup: Resolves scanned barcodes to product names.
    init(
        normalizer: IngredientNormalizerServiceProtocol,
        barcodeLookup: BarcodeProductLookupServiceProtocol = BarcodeProductLookupService()
    ) {
        self.normalizer = normalizer
        self.barcodeLookup = barcodeLookup
    }

    // MARK: - Methods

    /// Attempts to add the current `rawInput` as a validated ingredient.
    ///
    /// If the normaliser recognises the input, the canonical name is appended
    /// to `ingredients`, `rawInput` is cleared, and `validationError` is set
    /// to `nil`. If the input is unrecognised, `validationError` is set to
    /// `.unrecognized(rawName:)` and the list is unchanged.
    func addIngredient() {
        if let canonical = normalizer.normalize(rawInput) {
            ingredients.append(canonical)
            rawInput = ""
            validationError = nil
        } else {
            validationError = .unrecognized(rawName: rawInput)
        }
    }

    /// Removes the ingredient at the given index from `ingredients`.
    ///
    /// - Parameter index: The zero-based index of the ingredient to remove.
    func removeIngredient(at index: Int) {
        ingredients.remove(at: index)
    }

    /// Validates that the ingredient list is non-empty before recipe submission.
    ///
    /// - Returns: `true` if `ingredients` is non-empty; `false` otherwise.
    ///   Sets `validationError` to `.emptyList` when returning `false`, or
    ///   clears it when returning `true`.
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

    /// Resolves a scanned barcode to a product name via `BarcodeProductLookupService`,
    /// then attempts to normalise it. On success the canonical name is appended to
    /// `ingredients`. On failure `barcodeError` is set with a user-facing message.
    ///
    /// - Parameter barcode: The raw barcode string from the scanner.
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
                // Direct match — add immediately.
                if !ingredients.contains(canonical) {
                    ingredients.append(canonical)
                }
                barcodeError = nil
            } else {
                // Product found but name not in synonym dictionary.
                // Pre-fill the text field so the user can review/correct it.
                rawInput = productName
                barcodeError = "Found '\(productName)' — not in our ingredient list. You can edit and add it manually."
            }
        }
    }
}
