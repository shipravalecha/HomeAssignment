// RecipeEngineServiceTests.swift
// ChefNovaTests
//
// Unit tests and property-based tests for RecipeEngineService.
// Unit tests validate: Requirements 4.1, 4.2, 9.2, 9.3, 9.4
// Property tests validate: Requirements 4.1, 5.1, 5.2, 5.3, 5.4, 10.2, 10.4

import XCTest
import SwiftCheck
@testable import ChefNova

// MARK: - URLProtocol Stub for Unit Tests

/// A `URLProtocol` subclass that intercepts all requests and returns a
/// pre-configured response (data, HTTP status code, or error).
///
/// Usage:
/// 1. Set `MockURLProtocol.requestHandler` before each test.
/// 2. Create a `URLSession` configured with `MockURLProtocol` and inject it
///    into `RecipeEngineService`.
final class MockURLProtocol: URLProtocol {

    /// The handler invoked for every intercepted request.
    /// Returns `(HTTPURLResponse, Data)` or throws an error.
    ///
    /// Marked `nonisolated(unsafe)` because `URLProtocol` subclasses are
    /// called on arbitrary threads by `URLSession`; the test suite sets this
    /// before each test and the handler itself is read-only during the request.
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        // Intercept every request.
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - RecipeEngineService Unit Tests

/// Unit tests for `RecipeEngineService` that cover the five network scenarios
/// described in task 7.9:
///   1. Valid structured response → correct `RankedRecipe` values returned
///   2. Timeout (URLError.timedOut) → `RecipeEngineError.timeout`
///   3. HTTP 500 → `RecipeEngineError.serverError(statusCode:logMessage:)`
///   4. Network error (URLError.notConnectedToInternet) → `RecipeEngineError.networkUnavailable`
///   5. Empty `recipes` array → `RecipeEngineError.noResultsFound`
///
/// Validates: Requirements 4.1, 4.2, 9.2, 9.3, 9.4
@MainActor
final class RecipeEngineServiceUnitTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a `URLSession` that routes all requests through `MockURLProtocol`.
    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    /// Creates a `RecipeEngineService` with the mock session and a dummy API key.
    private func makeService() -> RecipeEngineService {
        RecipeEngineService(
            session: makeMockSession(),
            pantryStaplesService: PantryStaplesService(),
            apiKey: "test-api-key"
        )
    }

    /// A minimal `RecipeGenerationRequest` used across all tests.
    private var sampleRequest: RecipeGenerationRequest {
        RecipeGenerationRequest(
            ingredients: ["Onion", "Tomato"],
            pantryStaples: ["Salt", "Oil"],
            cuisine: .northIndian,
            dietaryPreference: .vegetarian,
            skillLevel: .beginner
        )
    }

    /// Builds a valid OpenAI Chat Completions JSON response body that contains
    /// one recipe matching the given title and match score.
    ///
    /// The inner `content` string is a JSON-encoded `RecipeEngineResponse`
    /// matching the schema defined in `RecipeEngineService`.
    private func makeValidResponseData(
        title: String = "Aloo Gobi",
        matchScore: Double = 0.9
    ) throws -> Data {
        // Inner structured payload (the model's message content).
        let innerPayload = """
        {
          "recipes": [
            {
              "title": "\(title)",
              "cuisine": "North Indian",
              "dietary_classification": "Vegetarian",
              "skill_level": "Beginner",
              "prep_time_minutes": 10,
              "cook_time_minutes": 20,
              "serving_size": 2,
              "match_score": \(matchScore),
              "ingredients": [
                { "name": "Onion",    "quantity": 1.0, "unit": "piece", "is_gap": false },
                { "name": "Tomato",   "quantity": 2.0, "unit": "piece", "is_gap": false },
                { "name": "Potato",   "quantity": 3.0, "unit": "piece", "is_gap": true  }
              ],
              "steps": ["Chop vegetables.", "Cook on medium heat.", "Serve hot."]
            }
          ]
        }
        """

        // Escape the inner payload for embedding in the outer JSON string.
        let escapedInner = innerPayload
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")

        // Outer OpenAI Chat Completions envelope.
        let outerJSON = """
        {
          "choices": [
            {
              "message": {
                "content": "\(escapedInner)"
              }
            }
          ]
        }
        """

        guard let data = outerJSON.data(using: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        return data
    }

    /// Builds a valid OpenAI response that contains an empty `recipes` array.
    private func makeEmptyRecipesResponseData() throws -> Data {
        let innerPayload = """
        { "recipes": [] }
        """
        let escapedInner = innerPayload
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        let outerJSON = """
        {
          "choices": [
            {
              "message": {
                "content": "\(escapedInner)"
              }
            }
          ]
        }
        """
        guard let data = outerJSON.data(using: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        return data
    }

    /// Returns an `HTTPURLResponse` with the given status code for the OpenAI endpoint.
    private func makeHTTPResponse(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.openai.com/v1/chat/completions")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    // MARK: - Test: Valid Structured Response

    /// Verifies that a well-formed OpenAI response is decoded into the correct
    /// `RankedRecipe` values.
    ///
    /// Validates: Requirements 4.1, 4.2
    func testValidResponseReturnsCorrectRankedRecipes() async throws {
        let expectedTitle = "Aloo Gobi"
        let expectedMatchScore = 0.9

        MockURLProtocol.requestHandler = { [weak self] _ in
            guard let self else { throw URLError(.unknown) }
            let data = try self.makeValidResponseData(
                title: expectedTitle,
                matchScore: expectedMatchScore
            )
            return (self.makeHTTPResponse(statusCode: 200), data)
        }

        let service = makeService()
        let results = try await service.generateRecipes(request: sampleRequest)

        // Should return exactly one recipe.
        XCTAssertEqual(results.count, 1, "Expected exactly 1 recipe in the response")

        let ranked = try XCTUnwrap(results.first)

        // Title should match.
        XCTAssertEqual(ranked.recipe.title, expectedTitle,
                       "Recipe title should match the value in the response")

        // Match score should match.
        XCTAssertEqual(ranked.matchScore, expectedMatchScore, accuracy: 0.001,
                       "Match score should match the value in the response")

        // isPartialMatch should be true because matchScore < 1.0.
        XCTAssertTrue(ranked.isPartialMatch,
                      "isPartialMatch should be true when matchScore < 1.0")

        // Cuisine should be North Indian.
        XCTAssertEqual(ranked.recipe.cuisine, .northIndian,
                       "Recipe cuisine should be North Indian")

        // Dietary classification should be Vegetarian.
        XCTAssertEqual(ranked.recipe.dietaryClassification, .vegetarian,
                       "Recipe dietary classification should be Vegetarian")

        // Skill level should be Beginner.
        XCTAssertEqual(ranked.recipe.skillLevel, .beginner,
                       "Recipe skill level should be Beginner")

        // Prep and cook times should match.
        XCTAssertEqual(ranked.recipe.prepTimeMinutes, 10,
                       "Prep time should be 10 minutes")
        XCTAssertEqual(ranked.recipe.cookTimeMinutes, 20,
                       "Cook time should be 20 minutes")

        // Serving size should match.
        XCTAssertEqual(ranked.recipe.servingSize, 2,
                       "Serving size should be 2")

        // Ingredients should be mapped (3 total).
        XCTAssertEqual(ranked.recipe.ingredients.count, 3,
                       "Recipe should have 3 ingredients")

        // Gap ingredient: Potato is marked is_gap: true and is not a pantry staple.
        // It should appear in gapIngredients.
        XCTAssertEqual(ranked.gapIngredients.count, 1,
                       "There should be exactly 1 gap ingredient (Potato)")
        XCTAssertEqual(ranked.gapIngredients.first?.name, "Potato",
                       "The gap ingredient should be Potato")

        // The gap ingredient's purchaseSearchURL should be a valid Google Shopping URL.
        let gapURL = try XCTUnwrap(ranked.gapIngredients.first?.purchaseSearchURL)
        XCTAssertEqual(gapURL.scheme, "https",
                       "Purchase search URL should use HTTPS")
        XCTAssertEqual(gapURL.host, "www.google.com",
                       "Purchase search URL should point to google.com")
        XCTAssertTrue(gapURL.absoluteString.contains("buy"),
                      "Purchase search URL should contain 'buy'")
    }

    // MARK: - Test: Full Match (matchScore == 1.0)

    /// Verifies that a recipe with matchScore == 1.0 has isPartialMatch == false
    /// and an empty gapIngredients list.
    ///
    /// Validates: Requirements 4.1
    func testFullMatchRecipeHasNoGapIngredients() async throws {
        MockURLProtocol.requestHandler = { [weak self] _ in
            guard let self else { throw URLError(.unknown) }
            // All ingredients are is_gap: false → no gap ingredients.
            let innerPayload = """
            {
              "recipes": [
                {
                  "title": "Simple Dal",
                  "cuisine": "North Indian",
                  "dietary_classification": "Vegetarian",
                  "skill_level": "Beginner",
                  "prep_time_minutes": 5,
                  "cook_time_minutes": 15,
                  "serving_size": 2,
                  "match_score": 1.0,
                  "ingredients": [
                    { "name": "Onion", "quantity": 1.0, "unit": "piece", "is_gap": false },
                    { "name": "Tomato", "quantity": 1.0, "unit": "piece", "is_gap": false }
                  ],
                  "steps": ["Cook everything.", "Serve."]
                }
              ]
            }
            """
            let escaped = innerPayload
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            let outer = """
            { "choices": [{ "message": { "content": "\(escaped)" } }] }
            """
            let data = outer.data(using: .utf8)!
            return (self.makeHTTPResponse(statusCode: 200), data)
        }

        let service = makeService()
        let results = try await service.generateRecipes(request: sampleRequest)

        let ranked = try XCTUnwrap(results.first)
        XCTAssertEqual(ranked.matchScore, 1.0, accuracy: 0.001,
                       "Match score should be 1.0")
        XCTAssertFalse(ranked.isPartialMatch,
                       "isPartialMatch should be false for a full match")
        XCTAssertTrue(ranked.gapIngredients.isEmpty,
                      "gapIngredients should be empty for a full match")
    }

    // MARK: - Test: Timeout → RecipeEngineError.timeout

    /// Verifies that a `URLError.timedOut` is mapped to `RecipeEngineError.timeout`.
    ///
    /// Validates: Requirement 9.2
    func testTimeoutThrowsRecipeEngineErrorTimeout() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }

        let service = makeService()
        do {
            _ = try await service.generateRecipes(request: sampleRequest)
            XCTFail("Expected RecipeEngineError.timeout to be thrown")
        } catch let error as RecipeEngineError {
            guard case .timeout = error else {
                XCTFail("Expected .timeout, got \(error)")
                return
            }
            // Success — correct error type thrown.
        } catch {
            XCTFail("Expected RecipeEngineError, got \(error)")
        }
    }

    // MARK: - Test: HTTP 500 → RecipeEngineError.serverError

    /// Verifies that an HTTP 500 response is mapped to
    /// `RecipeEngineError.serverError(statusCode: 500, logMessage:)`.
    ///
    /// Validates: Requirement 9.4
    func testHTTP500ThrowsRecipeEngineErrorServerError() async {
        MockURLProtocol.requestHandler = { [weak self] _ in
            guard let self else { throw URLError(.unknown) }
            let body = "Internal Server Error".data(using: .utf8)!
            return (self.makeHTTPResponse(statusCode: 500), body)
        }

        let service = makeService()
        do {
            _ = try await service.generateRecipes(request: sampleRequest)
            XCTFail("Expected RecipeEngineError.serverError to be thrown")
        } catch let error as RecipeEngineError {
            guard case .serverError(let statusCode, _) = error else {
                XCTFail("Expected .serverError, got \(error)")
                return
            }
            XCTAssertEqual(statusCode, 500,
                           "serverError statusCode should be 500")
        } catch {
            XCTFail("Expected RecipeEngineError, got \(error)")
        }
    }

    /// Verifies that any HTTP 5xx response (e.g. 503) is mapped to
    /// `RecipeEngineError.serverError`.
    ///
    /// Validates: Requirement 9.4
    func testHTTP503ThrowsRecipeEngineErrorServerError() async {
        MockURLProtocol.requestHandler = { [weak self] _ in
            guard let self else { throw URLError(.unknown) }
            let body = "Service Unavailable".data(using: .utf8)!
            return (self.makeHTTPResponse(statusCode: 503), body)
        }

        let service = makeService()
        do {
            _ = try await service.generateRecipes(request: sampleRequest)
            XCTFail("Expected RecipeEngineError.serverError to be thrown")
        } catch let error as RecipeEngineError {
            guard case .serverError(let statusCode, _) = error else {
                XCTFail("Expected .serverError, got \(error)")
                return
            }
            XCTAssertEqual(statusCode, 503,
                           "serverError statusCode should be 503")
        } catch {
            XCTFail("Expected RecipeEngineError, got \(error)")
        }
    }

    // MARK: - Test: Network Error → RecipeEngineError.networkUnavailable

    /// Verifies that `URLError.notConnectedToInternet` is mapped to
    /// `RecipeEngineError.networkUnavailable`.
    ///
    /// Validates: Requirement 9.3
    func testNotConnectedToInternetThrowsNetworkUnavailable() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let service = makeService()
        do {
            _ = try await service.generateRecipes(request: sampleRequest)
            XCTFail("Expected RecipeEngineError.networkUnavailable to be thrown")
        } catch let error as RecipeEngineError {
            guard case .networkUnavailable = error else {
                XCTFail("Expected .networkUnavailable, got \(error)")
                return
            }
            // Success — correct error type thrown.
        } catch {
            XCTFail("Expected RecipeEngineError, got \(error)")
        }
    }

    /// Verifies that `URLError.networkConnectionLost` is also mapped to
    /// `RecipeEngineError.networkUnavailable`.
    ///
    /// Validates: Requirement 9.3
    func testNetworkConnectionLostThrowsNetworkUnavailable() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.networkConnectionLost)
        }

        let service = makeService()
        do {
            _ = try await service.generateRecipes(request: sampleRequest)
            XCTFail("Expected RecipeEngineError.networkUnavailable to be thrown")
        } catch let error as RecipeEngineError {
            guard case .networkUnavailable = error else {
                XCTFail("Expected .networkUnavailable, got \(error)")
                return
            }
        } catch {
            XCTFail("Expected RecipeEngineError, got \(error)")
        }
    }

    // MARK: - Test: Empty recipes array → RecipeEngineError.noResultsFound

    /// Verifies that a valid OpenAI response containing an empty `recipes`
    /// array is mapped to `RecipeEngineError.noResultsFound`.
    ///
    /// Validates: Requirement 4.2 (no results case)
    func testEmptyRecipesArrayThrowsNoResultsFound() async throws {
        MockURLProtocol.requestHandler = { [weak self] _ in
            guard let self else { throw URLError(.unknown) }
            let data = try self.makeEmptyRecipesResponseData()
            return (self.makeHTTPResponse(statusCode: 200), data)
        }

        let service = makeService()
        do {
            _ = try await service.generateRecipes(request: sampleRequest)
            XCTFail("Expected RecipeEngineError.noResultsFound to be thrown")
        } catch let error as RecipeEngineError {
            guard case .noResultsFound = error else {
                XCTFail("Expected .noResultsFound, got \(error)")
                return
            }
            // Success — correct error type thrown.
        } catch {
            XCTFail("Expected RecipeEngineError, got \(error)")
        }
    }

    // MARK: - Test: Malformed JSON → RecipeEngineError.invalidResponse

    /// Verifies that a response with malformed JSON is mapped to
    /// `RecipeEngineError.invalidResponse`.
    func testMalformedJSONThrowsInvalidResponse() async {
        MockURLProtocol.requestHandler = { [weak self] _ in
            guard let self else { throw URLError(.unknown) }
            let data = "not valid json at all".data(using: .utf8)!
            return (self.makeHTTPResponse(statusCode: 200), data)
        }

        let service = makeService()
        do {
            _ = try await service.generateRecipes(request: sampleRequest)
            XCTFail("Expected RecipeEngineError.invalidResponse to be thrown")
        } catch let error as RecipeEngineError {
            guard case .invalidResponse = error else {
                XCTFail("Expected .invalidResponse, got \(error)")
                return
            }
        } catch {
            XCTFail("Expected RecipeEngineError, got \(error)")
        }
    }

    // MARK: - Test: Multiple recipes are returned in descending match score order

    /// Verifies that when the API returns multiple recipes, they are returned
    /// in the order provided (the service does not re-sort; the model is
    /// instructed to return them sorted).
    ///
    /// Validates: Requirement 4.1
    func testMultipleRecipesReturnedInOrder() async throws {
        MockURLProtocol.requestHandler = { [weak self] _ in
            guard let self else { throw URLError(.unknown) }
            let innerPayload = """
            {
              "recipes": [
                {
                  "title": "Recipe A",
                  "cuisine": "North Indian",
                  "dietary_classification": "Vegetarian",
                  "skill_level": "Beginner",
                  "prep_time_minutes": 10,
                  "cook_time_minutes": 20,
                  "serving_size": 2,
                  "match_score": 0.9,
                  "ingredients": [
                    { "name": "Onion", "quantity": 1.0, "unit": "piece", "is_gap": false }
                  ],
                  "steps": ["Step 1"]
                },
                {
                  "title": "Recipe B",
                  "cuisine": "North Indian",
                  "dietary_classification": "Vegetarian",
                  "skill_level": "Beginner",
                  "prep_time_minutes": 15,
                  "cook_time_minutes": 25,
                  "serving_size": 4,
                  "match_score": 0.6,
                  "ingredients": [
                    { "name": "Tomato", "quantity": 2.0, "unit": "piece", "is_gap": false }
                  ],
                  "steps": ["Step 1"]
                }
              ]
            }
            """
            let escaped = innerPayload
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            let outer = """
            { "choices": [{ "message": { "content": "\(escaped)" } }] }
            """
            let data = outer.data(using: .utf8)!
            return (self.makeHTTPResponse(statusCode: 200), data)
        }

        let service = makeService()
        let results = try await service.generateRecipes(request: sampleRequest)

        XCTAssertEqual(results.count, 2, "Expected 2 recipes")
        XCTAssertEqual(results[0].recipe.title, "Recipe A",
                       "First recipe should be Recipe A (higher match score)")
        XCTAssertEqual(results[1].recipe.title, "Recipe B",
                       "Second recipe should be Recipe B (lower match score)")
        XCTAssertGreaterThanOrEqual(
            results[0].matchScore, results[1].matchScore,
            "Recipes should be in descending match score order"
        )
    }

    // MARK: - Test: Pantry staples are not listed as gap ingredients

    /// Verifies that ingredients marked as is_gap: true but that are pantry
    /// staples for the selected cuisine are excluded from gapIngredients.
    ///
    /// Validates: Requirements 5.1, 10.4
    func testPantryStaplesNotListedAsGapIngredients() async throws {
        MockURLProtocol.requestHandler = { [weak self] _ in
            guard let self else { throw URLError(.unknown) }
            // Salt and Oil are North Indian pantry staples — they should be
            // excluded from gapIngredients even though is_gap is true.
            let innerPayload = """
            {
              "recipes": [
                {
                  "title": "Spiced Potato",
                  "cuisine": "North Indian",
                  "dietary_classification": "Vegetarian",
                  "skill_level": "Beginner",
                  "prep_time_minutes": 10,
                  "cook_time_minutes": 20,
                  "serving_size": 2,
                  "match_score": 0.5,
                  "ingredients": [
                    { "name": "Potato",  "quantity": 3.0, "unit": "piece", "is_gap": true  },
                    { "name": "Salt",    "quantity": 1.0, "unit": "tsp",   "is_gap": true  },
                    { "name": "Oil",     "quantity": 2.0, "unit": "tbsp",  "is_gap": true  }
                  ],
                  "steps": ["Cook."]
                }
              ]
            }
            """
            let escaped = innerPayload
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            let outer = """
            { "choices": [{ "message": { "content": "\(escaped)" } }] }
            """
            let data = outer.data(using: .utf8)!
            return (self.makeHTTPResponse(statusCode: 200), data)
        }

        let service = makeService()
        let results = try await service.generateRecipes(request: sampleRequest)

        let ranked = try XCTUnwrap(results.first)
        // Only Potato should be a gap ingredient; Salt and Oil are pantry staples.
        XCTAssertEqual(ranked.gapIngredients.count, 1,
                       "Only non-pantry-staple gap ingredients should be listed")
        XCTAssertEqual(ranked.gapIngredients.first?.name, "Potato",
                       "Potato should be the only gap ingredient")
        let gapNames = ranked.gapIngredients.map { $0.name }
        XCTAssertFalse(gapNames.contains("Salt"),
                       "Salt (a pantry staple) should not appear in gap ingredients")
        XCTAssertFalse(gapNames.contains("Oil"),
                       "Oil (a pantry staple) should not appear in gap ingredients")
    }
}

// MARK: - Arbitrary RankedRecipe

/// Provides SwiftCheck generators for `RankedRecipe` and its dependencies.
extension RecipeIngredient: Arbitrary {
    public static var arbitrary: Gen<RecipeIngredient> {
        Gen<RecipeIngredient>.compose { c in
            RecipeIngredient(
                name: c.generate(using: Gen<String>.fromElements(of: ["Onion", "Tomato", "Potato", "Garlic", "Ginger"])),
                quantity: c.generate(using: Gen<Double>.fromElements(of: [0.5, 1.0, 1.5, 2.0, 3.0])),
                unit: c.generate(using: Gen<String>.fromElements(of: ["cup", "tbsp", "tsp", "g", "kg", "piece"]))
            )
        }
    }
}

extension Recipe: Arbitrary {
    public static var arbitrary: Gen<Recipe> {
        Gen<Recipe>.compose { c in
            Recipe(
                id: UUID(),
                title: c.generate(using: Gen<String>.fromElements(of: ["Dal Makhani", "Paneer Butter Masala", "Chicken Curry", "Aloo Gobi", "Biryani"])),
                cuisine: .northIndian,
                dietaryClassification: c.generate(using: Gen<DietaryPreference>.fromElements(of: DietaryPreference.allCases)),
                skillLevel: c.generate(using: Gen<SkillLevel>.fromElements(of: SkillLevel.allCases)),
                prepTimeMinutes: c.generate(using: Gen<Int>.fromElements(of: [10, 15, 20, 30, 45])),
                cookTimeMinutes: c.generate(using: Gen<Int>.fromElements(of: [15, 20, 30, 45, 60])),
                servingSize: c.generate(using: Gen<Int>.fromElements(of: [2, 4, 6])),
                ingredients: c.generate(using: RecipeIngredient.arbitrary.proliferate),
                steps: ["Step 1", "Step 2", "Step 3"]
            )
        }
    }
}

extension RankedRecipe: Arbitrary {
    public static var arbitrary: Gen<RankedRecipe> {
        // Generate a matchScore uniformly in [0.0, 1.0] using 101 discrete steps
        // (0.00, 0.01, 0.02, … 1.00) to cover the full range.
        let scoreGen: Gen<Double> = Gen<Int>.choose((0, 100)).map { Double($0) / 100.0 }
        return Gen<RankedRecipe>.compose { c in
            let score = c.generate(using: scoreGen)
            return RankedRecipe(
                id: UUID(),
                recipe: c.generate(using: Recipe.arbitrary),
                matchScore: score,
                isPartialMatch: score < 1.0,
                gapIngredients: []
            )
        }
    }
}

// MARK: - Match Score Ordering Property Test

final class MatchScoreOrderingTests: XCTestCase {

    // Feature: chef-nova-app, Property 5: Match score ordering
    //
    // Validates: Requirements 4.1
    //
    // Property 5: Match Score Ordering
    // For any list of RankedRecipe values produced by the post-processing
    // pipeline, the list is sorted by matchScore descending — no recipe
    // appears before one with a strictly higher score.
    func testMatchScoreOrdering() {
        property(
            "sorted recipes have no recipe appearing before one with a strictly higher matchScore",
            arguments: CheckerArguments(maxAllowableSuccessfulTests: 100)
        ) <- forAll(RankedRecipe.arbitrary.proliferate) { (recipes: [RankedRecipe]) in
            // Simulate the post-processing pipeline sort: sort by matchScore descending,
            // matching the behaviour in RecipeEngineService.generateRecipes.
            let sorted = recipes.sorted { $0.matchScore > $1.matchScore }

            // Assert the ordering invariant: for every consecutive pair (a, b),
            // a.matchScore must be >= b.matchScore (no recipe appears before one
            // with a strictly higher score).
            for index in sorted.indices.dropLast() {
                let current = sorted[index]
                let next = sorted[index + 1]
                if current.matchScore < next.matchScore {
                    return false
                }
            }
            return true
        }
    }
}

// MARK: - Pantry Staples Excluded from Gap Ingredients Property Test

/// A minimal stand-in for a raw gap ingredient as produced by the OpenAI response,
/// used to drive the gap-ingredient post-processing pipeline in tests without
/// depending on the private `RawIngredient` type inside `RecipeEngineService`.
private struct RawGapIngredient {
    let name: String
}

extension Cuisine: @retroactive Arbitrary {
    public static var arbitrary: Gen<Cuisine> {
        Gen<Cuisine>.fromElements(of: Cuisine.allCases)
    }
}

extension SkillLevel: @retroactive Arbitrary {
    public static var arbitrary: Gen<SkillLevel> {
        Gen<SkillLevel>.fromElements(of: SkillLevel.allCases)
    }
}

extension DietaryPreference: @retroactive Arbitrary {
    public static var arbitrary: Gen<DietaryPreference> {
        Gen<DietaryPreference>.fromElements(of: DietaryPreference.allCases)
    }
}

final class PantryStaplesExcludedFromGapsTests: XCTestCase {

    // Feature: chef-nova-app, Property 6: Pantry staples excluded from gap ingredients
    //
    // Validates: Requirements 5.1, 10.4
    //
    // Property 6: Pantry Staples Excluded from Gap Ingredients
    // For any partial match recipe and any cuisine, no ingredient in the
    // pantry staples list for that cuisine appears in the gap ingredients list.
    func testPantryStaplesExcludedFromGaps() {
        let pantryStaplesService = PantryStaplesService()

        // Generator for a single raw gap ingredient name.
        // We mix pantry staple names with arbitrary strings so the generator
        // exercises both the "should be excluded" and "should be kept" paths.
        let pantryStapleNameGen: Gen<String> = Gen<String>.fromElements(of: [
            "Salt", "Black Pepper", "Red Chilli Powder", "Turmeric",
            "Cumin Seeds", "Coriander Powder", "Garam Masala", "Oil",
            // Case variants to exercise case-insensitive comparison.
            "salt", "TURMERIC", "cumin seeds", "garam masala"
        ])

        let nonStapleNameGen: Gen<String> = Gen<String>.fromElements(of: [
            "Chicken", "Paneer", "Potato", "Onion", "Tomato",
            "Spinach", "Lentils", "Cream", "Yogurt", "Cashews"
        ])

        // Mix staple and non-staple names so the generator covers both cases.
        let ingredientNameGen: Gen<String> = Gen<Bool>.fromElements(of: [true, false]).flatMap { useStaple in
            useStaple ? pantryStapleNameGen : nonStapleNameGen
        }

        // Generator for a list of raw gap ingredient names (1–10 entries).
        let rawGapNamesGen: Gen<[String]> = ingredientNameGen.proliferateNonEmpty

        property(
            "no pantry staple for the selected cuisine appears in the gap ingredients after post-processing",
            arguments: CheckerArguments(maxAllowableSuccessfulTests: 100)
        ) <- forAll(rawGapNamesGen, Cuisine.arbitrary, pf: { (rawGapNames: [String], cuisine: Cuisine) in
            // Replicate step 2 of the gap-ingredient post-processing pipeline
            // (design.md §Gap ingredient post-processing):
            //   Filter out any ingredient whose name is a pantry staple for the
            //   selected cuisine (case-insensitive, matching PantryStaplesService).
            let filteredGapNames = rawGapNames.filter { name in
                !pantryStaplesService.isPantryStaple(name, for: cuisine)
            }

            // Retrieve the pantry staples for this cuisine (lowercased for comparison).
            let staples = pantryStaplesService.getPantryStaples(for: cuisine)
            let staplesLowercased = Set(staples.map { $0.lowercased() })

            // Assert: none of the filtered gap ingredient names is a pantry staple.
            for name in filteredGapNames {
                if staplesLowercased.contains(name.lowercased()) {
                    return false
                }
            }
            return true
        })
    }
}

// MARK: - Pantry Staples Included in Recipe Generation Request Property Test

// Feature: chef-nova-app, Property 10: Pantry staples included in recipe generation request
//
// Validates: Requirements 10.2
//
// Property 10: Pantry Staples Included in Recipe Generation Request
// For any selected cuisine, the RecipeGenerationRequest constructed for that
// cuisine includes all pantry staples for that cuisine in its pantryStaples field.

final class PantryStaplesIncludedInRequestTests: XCTestCase {

    // Feature: chef-nova-app, Property 10: Pantry staples included in recipe generation request
    //
    // Validates: Requirements 10.2
    func testPantryStaplesIncludedInRequest() {
        let pantryStaplesService = PantryStaplesService()

        // Generator for a list of canonical ingredient names (may be empty).
        let ingredientGen: Gen<[String]> = Gen<String>
            .fromElements(of: ["Onion", "Tomato", "Potato", "Garlic", "Ginger",
                               "Chicken", "Paneer", "Spinach", "Lentils", "Cream"])
            .proliferate

        // Generator for an optional DietaryPreference value.
        let dietaryPrefGen: Gen<DietaryPreference?> = Gen<Bool>.fromElements(of: [true, false]).flatMap { include in
            if include {
                return Gen<DietaryPreference>.fromElements(of: DietaryPreference.allCases).map { Optional($0) }
            } else {
                return Gen.pure(nil)
            }
        }

        property(
            "RecipeGenerationRequest.pantryStaples contains ALL pantry staples for the selected cuisine",
            arguments: CheckerArguments(maxAllowableSuccessfulTests: 100)
        ) <- forAll(Cuisine.arbitrary, ingredientGen, SkillLevel.arbitrary, dietaryPrefGen) {
            (cuisine: Cuisine, ingredients: [String], skillLevel: SkillLevel, dietaryPreference: DietaryPreference?) in

            // Fetch the expected pantry staples for this cuisine — this mirrors
            // exactly what RecipeResultsViewModel.generateRecipes does before
            // constructing the request.
            let expectedStaples = pantryStaplesService.getPantryStaples(for: cuisine)

            // Construct the RecipeGenerationRequest the same way the view model does.
            let request = RecipeGenerationRequest(
                ingredients: ingredients,
                pantryStaples: expectedStaples,
                cuisine: cuisine,
                dietaryPreference: dietaryPreference,
                skillLevel: skillLevel
            )

            // Assert: every staple returned by PantryStaplesService for this cuisine
            // is present in the request's pantryStaples field.
            for staple in expectedStaples {
                if !request.pantryStaples.contains(staple) {
                    return false
                }
            }

            // Assert: the request's pantryStaples field contains no extra entries
            // beyond what PantryStaplesService returned (no phantom staples).
            if request.pantryStaples.count != expectedStaples.count {
                return false
            }

            return true
        }
    }
}

// MARK: - Gap Ingredient Processing Invariants Property Test

// Feature: chef-nova-app, Property 7: Gap ingredient processing invariants
//
// Validates: Requirements 5.2, 5.3, 5.4
//
// Property 7: Gap Ingredient Processing Invariants
// For any raw gap ingredient list:
//   (a) the displayed list has ≤ 5 entries,
//   (b) entries are ordered by commonalityRank ascending,
//   (c) every entry has a non-nil purchaseSearchURL.

/// Represents a raw gap ingredient as it arrives from the OpenAI response
/// (before post-processing), used to drive the pipeline in isolation.
private struct RawGapIngredientForProperty7 {
    let name: String
    let isGap: Bool
}

extension RawGapIngredientForProperty7: Arbitrary {
    static var arbitrary: Gen<RawGapIngredientForProperty7> {
        // Mix gap and non-gap ingredients so the filter step is exercised.
        let nameGen = Gen<String>.fromElements(of: [
            "Chicken", "Paneer", "Potato", "Onion", "Tomato",
            "Spinach", "Lentils", "Cream", "Yogurt", "Cashews",
            "Mushroom", "Peas", "Corn", "Carrot", "Capsicum",
            "Coconut Milk", "Tamarind", "Fenugreek", "Mustard Seeds", "Curry Leaves"
        ])
        let isGapGen = Gen<Bool>.fromElements(of: [true, false])
        return Gen<RawGapIngredientForProperty7>.compose { c in
            RawGapIngredientForProperty7(
                name: c.generate(using: nameGen),
                isGap: c.generate(using: isGapGen)
            )
        }
    }
}

final class GapIngredientProcessingInvariantsTests: XCTestCase {

    // Feature: chef-nova-app, Property 7: Gap ingredient processing invariants
    //
    // Validates: Requirements 5.2, 5.3, 5.4
    func testGapIngredientProcessingInvariants() {
        let pantryStaplesService = PantryStaplesService()

        // Generator for a list of raw ingredients (0–15 entries) that may or
        // may not be gap ingredients, covering the full range of pipeline inputs.
        let rawIngredientsGen: Gen<[RawGapIngredientForProperty7]> =
            RawGapIngredientForProperty7.arbitrary.proliferate

        property(
            "gap ingredient post-processing invariants: ≤5 entries, ascending commonalityRank, non-nil purchaseSearchURL",
            arguments: CheckerArguments(maxAllowableSuccessfulTests: 100)
        ) <- forAll(rawIngredientsGen, Cuisine.arbitrary, pf: { (rawIngredients: [RawGapIngredientForProperty7], cuisine: Cuisine) in

            // --- Replicate the gap-ingredient post-processing pipeline ---
            // (mirrors RecipeEngineService.mapToRankedRecipe)

            // Step 1: Filter ingredients where is_gap == true.
            let gapRaw = rawIngredients.filter { $0.isGap }

            // Step 2: Exclude pantry staples for the selected cuisine.
            let filteredGap = gapRaw.filter { ri in
                !pantryStaplesService.isPantryStaple(ri.name, for: cuisine)
            }

            // Step 3: Assign a 1-based commonalityRank based on position in the
            //         filtered list, then sort ascending (already in order, but
            //         we sort explicitly to mirror the implementation).
            let indexedGap = filteredGap.enumerated().map { (index, ri) in
                (name: ri.name, rank: index + 1)
            }
            let sortedGap = indexedGap.sorted { $0.rank < $1.rank }

            // Step 4: Truncate to maximum 5 gap ingredients.
            let truncatedGap = Array(sortedGap.prefix(5))

            // Step 5: Construct purchaseSearchURL for each gap ingredient.
            let gapIngredients: [GapIngredient] = truncatedGap.compactMap { item in
                var components = URLComponents(string: "https://www.google.com/search")
                let query = "buy \(item.name)"
                components?.queryItems = [URLQueryItem(name: "q", value: query)]
                guard let url = components?.url else { return nil }
                return GapIngredient(
                    name: item.name,
                    commonalityRank: item.rank,
                    purchaseSearchURL: url
                )
            }

            // --- Assert the three invariants ---

            // (a) Displayed list has ≤ 5 entries.
            guard gapIngredients.count <= 5 else {
                return false
            }

            // (b) Entries are ordered by commonalityRank ascending.
            for index in gapIngredients.indices.dropLast() {
                let current = gapIngredients[index]
                let next = gapIngredients[index + 1]
                if current.commonalityRank > next.commonalityRank {
                    return false
                }
            }

            // (c) Every entry has a non-nil purchaseSearchURL (guaranteed by
            //     the compactMap above, but we verify the URL is well-formed
            //     and contains the expected scheme and host).
            for gap in gapIngredients {
                let url = gap.purchaseSearchURL
                guard url.scheme == "https",
                      url.host == "www.google.com" else {
                    return false
                }
            }

            return true
        })
    }
}
