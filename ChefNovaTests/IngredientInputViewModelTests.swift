// IngredientInputViewModelTests.swift
// ChefNovaTests
//
// Unit tests for IngredientInputViewModel.
// Validates: Requirements 1.2, 1.4, 1.5, 1.7

import XCTest
@testable import ChefNova

// MARK: - Mock IngredientNormalizerService

/// A test double for `IngredientNormalizerServiceProtocol` that returns a
/// configurable canonical name or nil, without touching the real synonym
/// dictionary. This keeps the tests fast and deterministic.
///
/// By default:
///   - "Onion" (and any case variant) → "Onion"
///   - Everything else → nil (unrecognized)
private final class MockIngredientNormalizerService: IngredientNormalizerServiceProtocol {

    /// Maps lowercased-trimmed raw names to canonical names.
    /// Populated at init so tests can supply any mapping they need.
    private let synonymMap: [String: String]

    /// Creates the mock with an explicit synonym map.
    ///
    /// - Parameter synonymMap: Keys are lowercased, trimmed raw names;
    ///   values are the canonical names to return.
    init(synonymMap: [String: String] = ["onion": "Onion"]) {
        self.synonymMap = synonymMap
    }

    func normalize(_ rawName: String) -> String? {
        let key = rawName.lowercased().trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        return synonymMap[key]
    }

    func isRecognized(_ rawName: String) -> Bool {
        normalize(rawName) != nil
    }
}

// MARK: - IngredientInputViewModelTests

/// Unit tests for `IngredientInputViewModel`.
///
/// Each test uses a `MockIngredientNormalizerService` injected at init so
/// the view model's logic is exercised in isolation from the real synonym
/// dictionary.
///
/// Validates: Requirements 1.2, 1.4, 1.5, 1.7
@MainActor
final class IngredientInputViewModelTests: XCTestCase {

    // MARK: - Helpers

    /// Returns a view model backed by the default mock (only "Onion" recognized).
    private func makeViewModel(
        synonymMap: [String: String] = ["onion": "Onion"]
    ) -> IngredientInputViewModel {
        let mock = MockIngredientNormalizerService(synonymMap: synonymMap)
        return IngredientInputViewModel(normalizer: mock)
    }

    // MARK: - addIngredient: recognized input (Requirement 1.2, 1.3)

    /// When `rawInput` is a recognized ingredient, `addIngredient()` SHALL
    /// append the canonical name to `ingredients` and clear `rawInput`.
    ///
    /// Validates: Requirement 1.2
    func testAddRecognizedIngredientAppendsToListAndClearsRawInput() {
        let viewModel = makeViewModel()
        viewModel.rawInput = "Onion"

        viewModel.addIngredient()

        XCTAssertEqual(viewModel.ingredients, ["Onion"],
                       "Recognized ingredient should be appended to the list")
        XCTAssertEqual(viewModel.rawInput, "",
                       "rawInput should be cleared after a successful add")
    }

    /// Adding a recognized ingredient also clears any pre-existing `validationError`.
    ///
    /// Validates: Requirement 1.2
    func testAddRecognizedIngredientClearsValidationError() {
        let viewModel = makeViewModel()
        // Seed a prior error to confirm it is cleared on success.
        viewModel.validationError = .unrecognized(rawName: "xyz123")
        viewModel.rawInput = "Onion"

        viewModel.addIngredient()

        XCTAssertNil(viewModel.validationError,
                     "validationError should be nil after a successful add")
    }

    /// Adding multiple recognized ingredients accumulates them in order.
    ///
    /// Validates: Requirement 1.2
    func testAddMultipleRecognizedIngredientsAccumulatesInOrder() {
        let synonymMap = ["onion": "Onion", "tomato": "Tomato", "garlic": "Garlic"]
        let viewModel = makeViewModel(synonymMap: synonymMap)

        viewModel.rawInput = "Onion"
        viewModel.addIngredient()

        viewModel.rawInput = "Tomato"
        viewModel.addIngredient()

        viewModel.rawInput = "Garlic"
        viewModel.addIngredient()

        XCTAssertEqual(viewModel.ingredients, ["Onion", "Tomato", "Garlic"],
                       "Ingredients should accumulate in insertion order")
    }

    /// Case-insensitive input ("onion", "ONION") is normalized and appended.
    ///
    /// Validates: Requirement 1.3
    func testAddRecognizedIngredientIsCaseInsensitive() {
        let viewModel = makeViewModel()
        viewModel.rawInput = "ONION"

        viewModel.addIngredient()

        XCTAssertEqual(viewModel.ingredients, ["Onion"],
                       "Case-insensitive input should normalize and be appended")
        XCTAssertEqual(viewModel.rawInput, "",
                       "rawInput should be cleared after a successful add")
    }

    // MARK: - addIngredient: unrecognized input (Requirement 1.4)

    /// When `rawInput` is unrecognized, `addIngredient()` SHALL set
    /// `validationError` to `.unrecognized(rawName:)` and leave `ingredients`
    /// unchanged.
    ///
    /// Validates: Requirement 1.4
    func testAddUnrecognizedIngredientSetsValidationErrorAndDoesNotModifyList() {
        let viewModel = makeViewModel()
        viewModel.rawInput = "xyz123"

        viewModel.addIngredient()

        // The list must remain empty.
        XCTAssertTrue(viewModel.ingredients.isEmpty,
                      "Ingredient list should not be modified for an unrecognized input")

        // The error must be set with the raw name preserved.
        guard case .unrecognized(let rawName) = viewModel.validationError else {
            XCTFail("validationError should be .unrecognized(rawName:) for an unrecognized input")
            return
        }
        XCTAssertEqual(rawName, "xyz123",
                       "validationError should carry the original rawName")
    }

    /// An unrecognized ingredient does not clear `rawInput`, so the user can
    /// correct the typo without re-typing the whole name.
    ///
    /// Validates: Requirement 1.4
    func testAddUnrecognizedIngredientDoesNotClearRawInput() {
        let viewModel = makeViewModel()
        viewModel.rawInput = "xyz123"

        viewModel.addIngredient()

        XCTAssertEqual(viewModel.rawInput, "xyz123",
                       "rawInput should not be cleared when the ingredient is unrecognized")
    }

    /// An unrecognized attempt after a successful add does not remove the
    /// previously added ingredient.
    ///
    /// Validates: Requirement 1.4
    func testAddUnrecognizedIngredientAfterSuccessfulAddPreservesExistingList() {
        let viewModel = makeViewModel()

        viewModel.rawInput = "Onion"
        viewModel.addIngredient()

        viewModel.rawInput = "xyz123"
        viewModel.addIngredient()

        XCTAssertEqual(viewModel.ingredients, ["Onion"],
                       "Previously added ingredients should not be removed on an unrecognized attempt")
    }

    // MARK: - removeIngredient(at:) (Requirement 1.5)

    /// `removeIngredient(at:)` SHALL remove the ingredient at the specified
    /// index, leaving all other entries intact.
    ///
    /// Validates: Requirement 1.5
    func testRemoveIngredientAtIndexRemovesCorrectEntry() {
        let synonymMap = ["onion": "Onion", "tomato": "Tomato", "garlic": "Garlic"]
        let viewModel = makeViewModel(synonymMap: synonymMap)

        // Build a list: ["Onion", "Tomato", "Garlic"]
        viewModel.rawInput = "Onion";  viewModel.addIngredient()
        viewModel.rawInput = "Tomato"; viewModel.addIngredient()
        viewModel.rawInput = "Garlic"; viewModel.addIngredient()

        // Remove the middle element ("Tomato" at index 1).
        viewModel.removeIngredient(at: 1)

        XCTAssertEqual(viewModel.ingredients, ["Onion", "Garlic"],
                       "Only the ingredient at the specified index should be removed")
    }

    /// Removing the first element shifts remaining elements correctly.
    ///
    /// Validates: Requirement 1.5
    func testRemoveIngredientAtFirstIndexShiftsRemainingElements() {
        let synonymMap = ["onion": "Onion", "tomato": "Tomato"]
        let viewModel = makeViewModel(synonymMap: synonymMap)

        viewModel.rawInput = "Onion";  viewModel.addIngredient()
        viewModel.rawInput = "Tomato"; viewModel.addIngredient()

        viewModel.removeIngredient(at: 0)

        XCTAssertEqual(viewModel.ingredients, ["Tomato"],
                       "Removing the first element should leave only the second")
    }

    /// Removing the last element leaves the preceding elements intact.
    ///
    /// Validates: Requirement 1.5
    func testRemoveIngredientAtLastIndexLeavesRemainingElements() {
        let synonymMap = ["onion": "Onion", "tomato": "Tomato"]
        let viewModel = makeViewModel(synonymMap: synonymMap)

        viewModel.rawInput = "Onion";  viewModel.addIngredient()
        viewModel.rawInput = "Tomato"; viewModel.addIngredient()

        viewModel.removeIngredient(at: 1)

        XCTAssertEqual(viewModel.ingredients, ["Onion"],
                       "Removing the last element should leave only the first")
    }

    /// Removing the only element results in an empty list.
    ///
    /// Validates: Requirement 1.5
    func testRemoveIngredientFromSingleElementListResultsInEmptyList() {
        let viewModel = makeViewModel()

        viewModel.rawInput = "Onion"
        viewModel.addIngredient()

        viewModel.removeIngredient(at: 0)

        XCTAssertTrue(viewModel.ingredients.isEmpty,
                      "Removing the only ingredient should result in an empty list")
    }

    // MARK: - validateForSubmission() (Requirement 1.7)

    /// `validateForSubmission()` SHALL return `false` and set
    /// `validationError` to `.emptyList` when `ingredients` is empty.
    ///
    /// Validates: Requirement 1.7
    func testValidateForSubmissionReturnsFalseWithEmptyList() {
        let viewModel = makeViewModel()

        let result = viewModel.validateForSubmission()

        XCTAssertFalse(result,
                       "validateForSubmission() should return false when the ingredient list is empty")
        guard case .emptyList = viewModel.validationError else {
            XCTFail("validationError should be .emptyList when the list is empty")
            return
        }
    }

    /// `validateForSubmission()` SHALL return `true` and clear
    /// `validationError` when `ingredients` contains at least one entry.
    ///
    /// Validates: Requirement 1.7
    func testValidateForSubmissionReturnsTrueWithAtLeastOneIngredient() {
        let viewModel = makeViewModel()

        viewModel.rawInput = "Onion"
        viewModel.addIngredient()

        let result = viewModel.validateForSubmission()

        XCTAssertTrue(result,
                      "validateForSubmission() should return true when the ingredient list is non-empty")
        XCTAssertNil(viewModel.validationError,
                     "validationError should be nil when validation passes")
    }

    /// A prior `.emptyList` error is cleared when `validateForSubmission()`
    /// is called again after an ingredient has been added.
    ///
    /// Validates: Requirement 1.7
    func testValidateForSubmissionClearsPriorEmptyListError() {
        let viewModel = makeViewModel()

        // First call: empty list → sets .emptyList error.
        _ = viewModel.validateForSubmission()
        XCTAssertNotNil(viewModel.validationError)

        // Add an ingredient, then validate again.
        viewModel.rawInput = "Onion"
        viewModel.addIngredient()
        let result = viewModel.validateForSubmission()

        XCTAssertTrue(result,
                      "validateForSubmission() should return true after an ingredient is added")
        XCTAssertNil(viewModel.validationError,
                     "validationError should be cleared when validation passes on the second call")
    }

    /// `validateForSubmission()` returns `false` even when the list was
    /// non-empty but all ingredients were subsequently removed.
    ///
    /// Validates: Requirement 1.7
    func testValidateForSubmissionReturnsFalseAfterAllIngredientsRemoved() {
        let viewModel = makeViewModel()

        viewModel.rawInput = "Onion"
        viewModel.addIngredient()
        viewModel.removeIngredient(at: 0)

        let result = viewModel.validateForSubmission()

        XCTAssertFalse(result,
                       "validateForSubmission() should return false after all ingredients are removed")
        guard case .emptyList = viewModel.validationError else {
            XCTFail("validationError should be .emptyList after all ingredients are removed")
            return
        }
    }
}
