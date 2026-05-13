// PantryStaplesServiceTests.swift
// ChefNovaTests
//
// Unit tests for PantryStaplesService.
// Validates: Requirements 10.1, 10.4

import XCTest
@testable import ChefNova

final class PantryStaplesServiceTests: XCTestCase {

    // The service under test, loaded with the real app bundle so it uses
    // the production PantryStaples.json.
    private var service: PantryStaplesService!

    override func setUp() {
        super.setUp()
        // Bundle(for:) resolves to the app bundle (the test host) where
        // PantryStaples.json is embedded as a resource.
        service = PantryStaplesService(bundle: Bundle(for: PantryStaplesService.self))
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - getPantryStaples Tests (Requirement 10.1)

    /// getPantryStaples(for: .northIndian) must return exactly 8 staples.
    func testGetPantryStaplesNorthIndianReturnsEightItems() {
        let staples = service.getPantryStaples(for: .northIndian)
        XCTAssertEqual(staples.count, 8,
                       "North Indian pantry staples should contain exactly 8 items")
    }

    /// getPantryStaples(for: .northIndian) must contain all 8 expected staple names.
    func testGetPantryStaplesNorthIndianContainsAllExpectedStaples() {
        let staples = service.getPantryStaples(for: .northIndian)
        let expectedStaples = [
            "Salt",
            "Black Pepper",
            "Red Chilli Powder",
            "Turmeric",
            "Cumin Seeds",
            "Coriander Powder",
            "Garam Masala",
            "Oil"
        ]
        for expected in expectedStaples {
            XCTAssertTrue(staples.contains(expected),
                          "North Indian staples should contain '\(expected)'")
        }
    }

    // MARK: - isPantryStaple Tests (Requirement 10.4)

    /// A known staple ("Salt") must return true.
    func testIsPantryStapleReturnsTrueForKnownStaple() {
        XCTAssertTrue(service.isPantryStaple("Salt", for: .northIndian),
                      "'Salt' is a known North Indian pantry staple and should return true")
    }

    /// An ingredient not in the staples list must return false.
    func testIsPantryStapleReturnsFalseForUnknownIngredient() {
        XCTAssertFalse(service.isPantryStaple("Saffron", for: .northIndian),
                       "'Saffron' is not a North Indian pantry staple and should return false")
    }

    /// Lookup must be case-insensitive: "salt" (lowercase) should match "Salt".
    func testIsPantryStapleCaseInsensitiveLowercase() {
        XCTAssertTrue(service.isPantryStaple("salt", for: .northIndian),
                      "'salt' (lowercase) should match 'Salt' case-insensitively")
    }

    /// Lookup must be case-insensitive: "TURMERIC" (uppercase) should match "Turmeric".
    func testIsPantryStapleCaseInsensitiveUppercase() {
        XCTAssertTrue(service.isPantryStaple("TURMERIC", for: .northIndian),
                      "'TURMERIC' (uppercase) should match 'Turmeric' case-insensitively")
    }

    /// Lookup must be case-insensitive: "gArAm MaSaLa" (mixed case) should match "Garam Masala".
    func testIsPantryStapleCaseInsensitiveMixedCase() {
        XCTAssertTrue(service.isPantryStaple("gArAm MaSaLa", for: .northIndian),
                      "'gArAm MaSaLa' (mixed case) should match 'Garam Masala' case-insensitively")
    }

    /// A completely unrelated string must return false.
    func testIsPantryStapleReturnsFalseForArbitraryString() {
        XCTAssertFalse(service.isPantryStaple("xyzzy", for: .northIndian),
                       "An arbitrary unrecognized string should return false")
    }
}
