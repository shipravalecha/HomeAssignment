// IngredientNormalizerServiceTests.swift
// ChefNovaTests
//
// Unit tests for IngredientNormalizerService.
// Validates: Requirements 1.3, 1.4, 7.2, 7.3

import XCTest
@testable import ChefNova

final class IngredientNormalizerServiceTests: XCTestCase {

    // The service under test, loaded with the real app bundle so it uses
    // the production SynonymDictionary.json.
    private var service: IngredientNormalizerService!

    override func setUp() {
        super.setUp()
        // Bundle(for:) resolves to the app bundle (the test host) where
        // SynonymDictionary.json is embedded as a resource.
        service = IngredientNormalizerService(bundle: Bundle(for: IngredientNormalizerService.self))
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - Synonym Mapping Tests (Requirement 1.3, 7.2)

    /// "onions" is a plural variant that should map to the canonical name "Onion".
    func testOnionsPluralMapsToOnion() {
        XCTAssertEqual(service.normalize("onions"), "Onion",
                       "'onions' should normalize to 'Onion'")
    }

    /// "tomatoes" is a plural variant that should map to the canonical name "Tomato".
    func testTomatoesPluralMapsToTomato() {
        XCTAssertEqual(service.normalize("tomatoes"), "Tomato",
                       "'tomatoes' should normalize to 'Tomato'")
    }

    /// "onion" (singular, lowercase) is itself a key in the dictionary.
    func testOnionSingularMapsToOnion() {
        XCTAssertEqual(service.normalize("onion"), "Onion",
                       "'onion' should normalize to 'Onion'")
    }

    /// "tomato" (singular, lowercase) is itself a key in the dictionary.
    func testTomatoSingularMapsToTomato() {
        XCTAssertEqual(service.normalize("tomato"), "Tomato",
                       "'tomato' should normalize to 'Tomato'")
    }

    /// "red onion" is a variant that should also map to "Onion".
    func testRedOnionVariantMapsToOnion() {
        XCTAssertEqual(service.normalize("red onion"), "Onion",
                       "'red onion' should normalize to 'Onion'")
    }

    /// "tamatar" (Hindi variant) should map to "Tomato".
    func testTamatarHindiVariantMapsToTomato() {
        XCTAssertEqual(service.normalize("tamatar"), "Tomato",
                       "'tamatar' should normalize to 'Tomato'")
    }

    /// "pyaz" (Hindi variant) should map to "Onion".
    func testPyazHindiVariantMapsToOnion() {
        XCTAssertEqual(service.normalize("pyaz"), "Onion",
                       "'pyaz' should normalize to 'Onion'")
    }

    // MARK: - Case-Insensitive Lookup Tests (Requirement 1.3, 7.2)

    /// All-uppercase "ONION" should normalize to "Onion".
    func testUppercaseOnionNormalizesToOnion() {
        XCTAssertEqual(service.normalize("ONION"), "Onion",
                       "'ONION' (all caps) should normalize to 'Onion'")
    }

    /// Title-case "Onion" should normalize to "Onion".
    func testTitleCaseOnionNormalizesToOnion() {
        XCTAssertEqual(service.normalize("Onion"), "Onion",
                       "'Onion' (title case) should normalize to 'Onion'")
    }

    /// Lowercase "onion" should normalize to "Onion".
    func testLowercaseOnionNormalizesToOnion() {
        XCTAssertEqual(service.normalize("onion"), "Onion",
                       "'onion' (lowercase) should normalize to 'Onion'")
    }

    /// Mixed-case "oNiOn" should normalize to "Onion".
    func testMixedCaseOnionNormalizesToOnion() {
        XCTAssertEqual(service.normalize("oNiOn"), "Onion",
                       "'oNiOn' (mixed case) should normalize to 'Onion'")
    }

    /// All-uppercase "TOMATO" should normalize to "Tomato".
    func testUppercaseTomatoNormalizesToTomato() {
        XCTAssertEqual(service.normalize("TOMATO"), "Tomato",
                       "'TOMATO' (all caps) should normalize to 'Tomato'")
    }

    /// Title-case "Tomato" should normalize to "Tomato".
    func testTitleCaseTomatoNormalizesToTomato() {
        XCTAssertEqual(service.normalize("Tomato"), "Tomato",
                       "'Tomato' (title case) should normalize to 'Tomato'")
    }

    // MARK: - Unrecognized Input Returns nil (Requirement 1.4, 7.3)

    /// A completely made-up word should return nil.
    func testUnrecognizedStringReturnsNil() {
        XCTAssertNil(service.normalize("xyzzy"),
                     "An unrecognized string should return nil")
    }

    /// A plausible but unknown ingredient name should return nil.
    func testUnknownIngredientNameReturnsNil() {
        XCTAssertNil(service.normalize("dragonberry"),
                     "An unknown ingredient name should return nil")
    }

    /// A numeric string should return nil.
    func testNumericStringReturnsNil() {
        XCTAssertNil(service.normalize("12345"),
                     "A numeric string should return nil")
    }

    /// A string with special characters only should return nil.
    func testSpecialCharactersOnlyReturnsNil() {
        XCTAssertNil(service.normalize("!@#$%"),
                     "A string with only special characters should return nil")
    }

    // MARK: - Whitespace-Only Input Returns nil (Requirement 9.5, 1.7)

    /// A single space should return nil.
    func testSingleSpaceReturnsNil() {
        XCTAssertNil(service.normalize(" "),
                     "A single space should return nil")
    }

    /// Multiple spaces should return nil.
    func testMultipleSpacesReturnNil() {
        XCTAssertNil(service.normalize("     "),
                     "A string of spaces should return nil")
    }

    /// A tab character should return nil.
    func testTabCharacterReturnsNil() {
        XCTAssertNil(service.normalize("\t"),
                     "A tab character should return nil")
    }

    /// A newline character should return nil.
    func testNewlineCharacterReturnsNil() {
        XCTAssertNil(service.normalize("\n"),
                     "A newline character should return nil")
    }

    /// A mix of whitespace characters (space, tab, newline) should return nil.
    func testMixedWhitespaceReturnsNil() {
        XCTAssertNil(service.normalize(" \t\n\r "),
                     "A string of mixed whitespace characters should return nil")
    }

    // MARK: - isRecognized Consistency Tests

    /// isRecognized should return true for a known synonym.
    func testIsRecognizedReturnsTrueForKnownSynonym() {
        XCTAssertTrue(service.isRecognized("onions"),
                      "isRecognized should return true for 'onions'")
    }

    /// isRecognized should return false for an unknown string.
    func testIsRecognizedReturnsFalseForUnknownString() {
        XCTAssertFalse(service.isRecognized("xyzzy"),
                       "isRecognized should return false for 'xyzzy'")
    }

    /// isRecognized should return false for a whitespace-only string.
    func testIsRecognizedReturnsFalseForWhitespace() {
        XCTAssertFalse(service.isRecognized("   "),
                       "isRecognized should return false for whitespace-only input")
    }
}
