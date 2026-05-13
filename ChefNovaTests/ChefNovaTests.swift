import XCTest
import SwiftCheck
@testable import ChefNova

// MARK: - Normalizer Idempotence Property Test

final class NormalizerIdempotenceTests: XCTestCase {

    // Feature: chef-nova-app, Property 1: Normalizer idempotence
    //
    // Validates: Requirements 7.4
    //
    // Property 1: Normalizer Idempotence
    // For any canonical name in the synonym dictionary,
    // normalize(normalize(x)) == normalize(x).
    func testNormalizerIdempotence() {
        // Load all canonical values from SynonymDictionary.json via the app bundle.
        // The test host is the ChefNova app, so Bundle(for: IngredientNormalizerService.self)
        // resolves to the app bundle where SynonymDictionary.json lives.
        let appBundle = Bundle(for: IngredientNormalizerService.self)
        guard
            let url = appBundle.url(forResource: "SynonymDictionary", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let synonymMap = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            XCTFail("Failed to load SynonymDictionary.json from app bundle")
            return
        }

        // Collect all unique canonical names (the values in the synonym map).
        let canonicalNames = Array(Set(synonymMap.values))
        XCTAssertFalse(canonicalNames.isEmpty, "Canonical names list must not be empty")

        let service = IngredientNormalizerService(bundle: appBundle)

        // Use SwiftCheck to pick from the canonical names and assert idempotence.
        // Gen.fromElements(of:) generates random elements from the provided array.
        property("normalize(normalize(x)) == normalize(x) for all canonical names", arguments: CheckerArguments(maxAllowableSuccessfulTests: 100)) <- forAll(Gen.fromElements(of: canonicalNames)) { canonicalName in
            let firstNormalization = service.normalize(canonicalName)
            let secondNormalization = firstNormalization.flatMap { service.normalize($0) }
            return firstNormalization == secondNormalization
        }
    }
}

// MARK: - Unrecognized Ingredient Returns Nil Property Test

final class UnrecognizedIngredientReturnsNilTests: XCTestCase {

    // Feature: chef-nova-app, Property 3: Unrecognized ingredient returns nil
    //
    // Validates: Requirements 1.4, 7.3
    //
    // Property 3: Unrecognized Ingredient Returns Nil
    // For any string that does not appear in the synonym dictionary
    // (neither as a key nor as a canonical value), normalize(_:) SHALL
    // return nil.
    func testUnrecognizedIngredientReturnsNil() {
        // Load the synonym dictionary from the app bundle.
        let appBundle = Bundle(for: IngredientNormalizerService.self)
        guard
            let url = appBundle.url(forResource: "SynonymDictionary", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let synonymMap = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            XCTFail("Failed to load SynonymDictionary.json from app bundle")
            return
        }

        // Build a set of all known strings: both variant keys and canonical values,
        // all lowercased and trimmed to match the service's internal lookup logic.
        var knownStrings = Set<String>()
        for (key, value) in synonymMap {
            knownStrings.insert(key.lowercased().trimmingCharacters(in: .whitespaces))
            knownStrings.insert(value.lowercased().trimmingCharacters(in: .whitespaces))
        }

        let service = IngredientNormalizerService(bundle: appBundle)

        // Generate arbitrary strings using SwiftCheck's built-in String generator.
        // Filter out any string whose lowercased-trimmed form is present in the
        // synonym dictionary (as a key or canonical value) — those are recognized
        // inputs and are out of scope for this property.
        // Assert that all remaining strings produce nil from normalize(_:).
        property("normalize returns nil for any string not in the synonym dictionary", arguments: CheckerArguments(maxAllowableSuccessfulTests: 100)) <- forAll { (s: String) in
            let normalized = s.lowercased().trimmingCharacters(in: .whitespaces)
            // Skip strings that are known to the dictionary.
            guard !normalized.isEmpty && !knownStrings.contains(normalized) else {
                return true // discard: empty or recognized — not in scope for this property
            }
            return service.normalize(s) == nil
        }
    }
}

// MARK: - Whitespace-Only Ingredient Rejection Property Test

final class WhitespaceIngredientRejectionTests: XCTestCase {

    // Feature: chef-nova-app, Property 4: Whitespace-only ingredients rejected
    //
    // Validates: Requirements 9.5, 1.7
    //
    // Property 4: Whitespace-Only Ingredients Are Rejected
    // For any string composed entirely of whitespace characters
    // (spaces, tabs, newlines, carriage returns), normalize(_:) SHALL
    // return nil — the normalizer treats whitespace-only input as
    // unrecognized, keeping the Ingredient List unchanged.
    func testWhitespaceIngredientRejection() {
        let appBundle = Bundle(for: IngredientNormalizerService.self)
        let service = IngredientNormalizerService(bundle: appBundle)

        // Generator for a single whitespace character chosen from the
        // four whitespace characters defined in the spec.
        let whitespaceCharGen: Gen<Character> = Gen<Character>.fromElements(of: [" ", "\t", "\n", "\r"])

        // Generator for a non-empty array of whitespace characters (1…20 elements).
        // `proliferateNonEmpty` produces arrays of at least one element.
        let whitespaceStringGen: Gen<String> = whitespaceCharGen
            .proliferateNonEmpty
            .map { chars in String(chars) }

        property("normalize returns nil for any whitespace-only string",
                 arguments: CheckerArguments(maxAllowableSuccessfulTests: 100)) <- forAll(whitespaceStringGen) { whitespaceString in
            return service.normalize(whitespaceString) == nil
        }
    }
}

// MARK: - Normalizer Round-Trip Stability Property Test

final class NormalizerRoundTripTests: XCTestCase {

    // Feature: chef-nova-app, Property 2: Normalizer round-trip stability
    //
    // Validates: Requirements 7.5, 1.3
    //
    // Property 2: Normalizer Round-Trip Stability
    // For any variant key in the synonym map, normalizing it and then
    // normalizing the result SHALL return the same canonical name as the
    // first normalization:
    //   normalize(normalize(variant)) == normalize(variant)
    func testNormalizerRoundTrip() {
        // Load the synonym dictionary from the app bundle.
        // The test host is the ChefNova app, so Bundle(for: IngredientNormalizerService.self)
        // resolves to the app bundle where SynonymDictionary.json lives.
        let appBundle = Bundle(for: IngredientNormalizerService.self)
        guard
            let url = appBundle.url(forResource: "SynonymDictionary", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let synonymMap = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            XCTFail("Failed to load SynonymDictionary.json from app bundle")
            return
        }

        // Collect all variant keys from the synonym map.
        // These are the raw input strings that map to canonical names.
        let variantKeys = Array(synonymMap.keys)
        XCTAssertFalse(variantKeys.isEmpty, "Variant keys list must not be empty")

        let service = IngredientNormalizerService(bundle: appBundle)

        // Use SwiftCheck to pick from the variant keys and assert round-trip stability.
        // For each variant: normalize(variant) -> canonical, then normalize(canonical)
        // must equal canonical (i.e., the second normalization is stable).
        property("normalize(normalize(variant)) == normalize(variant) for all variant keys", arguments: CheckerArguments(maxAllowableSuccessfulTests: 100)) <- forAll(Gen.fromElements(of: variantKeys)) { variant in
            // First normalization: variant -> canonical name
            guard let firstResult = service.normalize(variant) else {
                // A variant key in the synonym map must always normalize successfully.
                return false
            }
            // Second normalization: canonical name -> should return the same canonical name
            let secondResult = service.normalize(firstResult)
            return secondResult == firstResult
        }
    }
}
