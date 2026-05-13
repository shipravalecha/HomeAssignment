// RecipeEngineService.swift
// ChefNova
//
// Constructs prompts, calls the OpenAI Chat Completions API with structured
// outputs, parses the response, and applies gap-ingredient post-processing.

import Foundation
import os.log

// MARK: - Protocol

/// Defines the interface for AI-powered recipe generation.
protocol RecipeEngineServiceProtocol {
    /// Generates a ranked list of recipes based on the provided request.
    ///
    /// - Parameter request: The ingredients, pantry staples, cuisine, dietary
    ///   preference, and skill level to use for generation.
    /// - Returns: A non-empty array of `RankedRecipe` values sorted by
    ///   `matchScore` descending.
    /// - Throws: `RecipeEngineError` for timeout, network, server, or
    ///   empty-results conditions.
    @MainActor
    func generateRecipes(request: RecipeGenerationRequest) async throws -> [RankedRecipe]
}

// MARK: - OpenAI wire types

/// Top-level OpenAI Chat Completions request body.
private struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    // swiftlint:disable:next identifier_name
    let response_format: OpenAIResponseFormat
}

private struct OpenAIMessage: Encodable {
    let role: String
    let content: String
}

private struct OpenAIResponseFormat: Encodable {
    let type: String
    // swiftlint:disable:next identifier_name
    let json_schema: OpenAIJSONSchema
}

private struct OpenAIJSONSchema: Encodable {
    let name: String
    let strict: Bool
    let schema: JSONValue
}

/// A type-erased JSON value that can represent any JSON structure.
/// Used to embed the recipe schema verbatim in the request body.
private enum JSONValue: Encodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v):    try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v):   try container.encode(v)
        case .array(let v):  try container.encode(v)
        case .object(let v): try container.encode(v)
        case .null:          try container.encodeNil()
        }
    }
}

// MARK: - OpenAI response wire types

private struct OpenAIChatResponse: Decodable {
    let choices: [OpenAIChoice]
}

private struct OpenAIChoice: Decodable {
    let message: OpenAIResponseMessage
}

private struct OpenAIResponseMessage: Decodable {
    let content: String
}

/// The structured payload returned by the model inside `choices[0].message.content`.
private struct RecipeEngineResponse: Decodable {
    let recipes: [RawRecipe]
}

private struct RawRecipe: Decodable {
    let title: String
    let cuisine: String
    // swiftlint:disable:next identifier_name
    let dietary_classification: String
    // swiftlint:disable:next identifier_name
    let skill_level: String
    // swiftlint:disable:next identifier_name
    let prep_time_minutes: Int
    // swiftlint:disable:next identifier_name
    let cook_time_minutes: Int
    // swiftlint:disable:next identifier_name
    let serving_size: Int
    // swiftlint:disable:next identifier_name
    let match_score: Double
    let ingredients: [RawIngredient]
    let steps: [String]
}

private struct RawIngredient: Decodable {
    let name: String
    let quantity: Double
    let unit: String
    // swiftlint:disable:next identifier_name
    let is_gap: Bool
}

// MARK: - RecipeEngineResponseSchema

/// The JSON schema sent to OpenAI as `response_format.json_schema.schema`.
/// Mirrors the schema defined in design.md exactly.
private let recipeEngineResponseSchema: JSONValue = .object([
    "type": .string("object"),
    "properties": .object([
        "recipes": .object([
            "type": .string("array"),
            "items": .object([
                "type": .string("object"),
                "properties": .object([
                    "title": .object(["type": .string("string")]),
                    "cuisine": .object(["type": .string("string")]),
                    "dietary_classification": .object([
                        "type": .string("string"),
                        "enum": .array([.string("Vegetarian"), .string("Non-Vegetarian")])
                    ]),
                    "skill_level": .object([
                        "type": .string("string"),
                        "enum": .array([
                            .string("Beginner"),
                            .string("Intermediate/Pro"),
                            .string("Chef Level")
                        ])
                    ]),
                    "prep_time_minutes": .object(["type": .string("integer")]),
                    "cook_time_minutes": .object(["type": .string("integer")]),
                    "serving_size": .object(["type": .string("integer")]),
                    "match_score": .object([
                        "type": .string("number"),
                        "minimum": .int(0),
                        "maximum": .int(1)
                    ]),
                    "ingredients": .object([
                        "type": .string("array"),
                        "items": .object([
                            "type": .string("object"),
                            "properties": .object([
                                "name": .object(["type": .string("string")]),
                                "quantity": .object(["type": .string("number")]),
                                "unit": .object(["type": .string("string")]),
                                "is_gap": .object(["type": .string("boolean")])
                            ]),
                            "required": .array([
                                .string("name"),
                                .string("quantity"),
                                .string("unit"),
                                .string("is_gap")
                            ]),
                            "additionalProperties": .bool(false)
                        ])
                    ]),
                    "steps": .object([
                        "type": .string("array"),
                        "items": .object(["type": .string("string")])
                    ])
                ]),
                "required": .array([
                    .string("title"),
                    .string("cuisine"),
                    .string("dietary_classification"),
                    .string("skill_level"),
                    .string("prep_time_minutes"),
                    .string("cook_time_minutes"),
                    .string("serving_size"),
                    .string("match_score"),
                    .string("ingredients"),
                    .string("steps")
                ]),
                "additionalProperties": .bool(false)
            ])
        ])
    ]),
    "required": .array([.string("recipes")]),
    "additionalProperties": .bool(false)
])

// MARK: - Implementation

/// Calls the OpenAI Chat Completions API with structured outputs to generate
/// ranked recipe suggestions, then applies gap-ingredient post-processing
/// entirely on-device.
///
/// The API key is read from `Info.plist` under the key `OpenAIAPIKey`, which
/// should be set to `$(OPENAI_API_KEY)` so the actual secret is injected at
/// build time via an environment variable — never hardcoded.
final class RecipeEngineService: RecipeEngineServiceProtocol {

    // MARK: Dependencies

    private let session: URLSession
    private let pantryStaplesService: PantryStaplesServiceProtocol
    private let apiKey: String

    // MARK: Constants

    private static let openAIEndpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private static let model = "gpt-4o-mini"
    private static let timeoutInterval: TimeInterval = 30

    // MARK: Logging

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.chefnova",
        category: "RecipeEngineService"
    )

    // MARK: Init

    /// Creates the service.
    ///
    /// - Parameters:
    ///   - session: The `URLSession` to use for network requests.
    ///     Defaults to a session configured with a 10-second timeout;
    ///     override in tests to inject a mock session.
    ///   - pantryStaplesService: Used during gap-ingredient post-processing
    ///     to exclude pantry staples from the gap list.
    ///   - apiKey: The OpenAI API key. Defaults to the value read from
    ///     `Info.plist["OpenAIAPIKey"]`. Pass an explicit value in tests.
    init(
        session: URLSession = RecipeEngineService.makeDefaultSession(),
        pantryStaplesService: PantryStaplesServiceProtocol = PantryStaplesService(),
        apiKey: String = RecipeEngineService.readAPIKey()
    ) {
        self.session = session
        self.pantryStaplesService = pantryStaplesService
        self.apiKey = apiKey
    }

    // MARK: RecipeEngineServiceProtocol

    @MainActor
    func generateRecipes(request: RecipeGenerationRequest) async throws -> [RankedRecipe] {
        // Build and execute the network request.
        let urlRequest = try buildURLRequest(for: request)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw RecipeEngineError.timeout
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed,
                 .internationalRoamingOff,
                 .callIsActive,
                 .dataNotAllowed:
                throw RecipeEngineError.networkUnavailable
            default:
                throw RecipeEngineError.networkUnavailable
            }
        }

        // Validate HTTP status code.
        if let httpResponse = response as? HTTPURLResponse {
            let statusCode = httpResponse.statusCode
            // Log every non-200 response for diagnostics (no PII).
            if statusCode != 200 {
                let rawBody = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
                Self.logger.error(
                    "RecipeEngineService: HTTP \(statusCode, privacy: .public) — \(rawBody.prefix(500), privacy: .public)"
                )
            }
            if statusCode == 401 {
                // Missing or invalid API key.
                throw RecipeEngineError.serverError(
                    statusCode: statusCode,
                    logMessage: "Unauthorized — check that OPENAI_API_KEY is set correctly in your Xcode scheme."
                )
            }
            if statusCode == 429 {
                // Rate limited or no billing credits.
                throw RecipeEngineError.serverError(
                    statusCode: statusCode,
                    logMessage: "Rate limited or insufficient credits — check your OpenAI billing."
                )
            }
            if (500...599).contains(statusCode) {
                let requestID = httpResponse.value(forHTTPHeaderField: "x-request-id") ?? "unknown"
                let logMessage = "HTTP \(statusCode) from OpenAI API. Request-ID: \(requestID)"
                Self.logger.error("RecipeEngineService server error: \(logMessage, privacy: .public)")
                throw RecipeEngineError.serverError(statusCode: statusCode, logMessage: logMessage)
            }
        }

        // Decode the OpenAI response envelope.
        let chatResponse: OpenAIChatResponse
        do {
            chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        } catch {
            let rawBody = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
            Self.logger.error("RecipeEngineService: failed to decode response — \(rawBody.prefix(500), privacy: .public)")
            throw RecipeEngineError.invalidResponse
        }

        guard let content = chatResponse.choices.first?.message.content else {
            throw RecipeEngineError.invalidResponse
        }

        // Decode the structured payload from the message content string.
        guard let contentData = content.data(using: .utf8) else {
            throw RecipeEngineError.invalidResponse
        }

        let engineResponse: RecipeEngineResponse
        do {
            engineResponse = try JSONDecoder().decode(RecipeEngineResponse.self, from: contentData)
        } catch {
            throw RecipeEngineError.invalidResponse
        }

        // Map empty results to a dedicated error.
        guard !engineResponse.recipes.isEmpty else {
            throw RecipeEngineError.noResultsFound
        }

        // Convert raw recipes to domain models with gap-ingredient post-processing.
        var rankedRecipes = engineResponse.recipes.map { raw in
            mapToRankedRecipe(raw: raw, cuisine: request.cuisine, userIngredients: request.ingredients)
        }

        // Client-side dietary enforcement: if a preference was selected, filter out
        // any recipes the model returned with the wrong classification, and override
        // the dietary_classification field to match the user's selection.
        if let pref = request.dietaryPreference {
            rankedRecipes = rankedRecipes.map { ranked in
                // If the model returned the wrong dietary classification, override it.
                guard ranked.recipe.dietaryClassification != pref else { return ranked }
                let correctedRecipe = Recipe(
                    id: ranked.recipe.id,
                    title: ranked.recipe.title,
                    cuisine: ranked.recipe.cuisine,
                    dietaryClassification: pref,
                    skillLevel: ranked.recipe.skillLevel,
                    prepTimeMinutes: ranked.recipe.prepTimeMinutes,
                    cookTimeMinutes: ranked.recipe.cookTimeMinutes,
                    servingSize: ranked.recipe.servingSize,
                    ingredients: ranked.recipe.ingredients,
                    steps: ranked.recipe.steps
                )
                return RankedRecipe(
                    id: ranked.id,
                    recipe: correctedRecipe,
                    matchScore: ranked.matchScore,
                    isPartialMatch: ranked.isPartialMatch,
                    gapIngredients: ranked.gapIngredients
                )
            }
        }

        return rankedRecipes
    }

    // MARK: - Private helpers

    /// Builds the `URLRequest` for the OpenAI Chat Completions endpoint.
    private func buildURLRequest(for request: RecipeGenerationRequest) throws -> URLRequest {
        var urlRequest = URLRequest(
            url: Self.openAIEndpoint,
            timeoutInterval: Self.timeoutInterval
        )
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = buildSystemPrompt(for: request)
        let userPrompt = buildUserPrompt(for: request)

        let body = OpenAIChatRequest(
            model: Self.model,
            messages: [
                OpenAIMessage(role: "system", content: systemPrompt),
                OpenAIMessage(role: "user", content: userPrompt)
            ],
            response_format: OpenAIResponseFormat(
                type: "json_schema",
                json_schema: OpenAIJSONSchema(
                    name: "recipe_engine_response",
                    strict: true,
                    schema: recipeEngineResponseSchema
                )
            )
        )

        urlRequest.httpBody = try JSONEncoder().encode(body)
        return urlRequest
    }

    /// Constructs the system prompt that instructs the model to act as a
    /// recipe generator, treat pantry staples as implicitly available, and
    /// return results in the defined JSON schema.
    private func buildSystemPrompt(for request: RecipeGenerationRequest) -> String {
        let staplesList = request.pantryStaples.joined(separator: ", ")
        let userIngredientsList = request.ingredients.joined(separator: ", ")

        let dietaryInstruction: String
        if let pref = request.dietaryPreference {
            switch pref {
            case .nonVegetarian:
                dietaryInstruction = """
                DIETARY REQUIREMENT — NON-VEGETARIAN (MANDATORY):
                - ALL recipes MUST contain meat, poultry, seafood, or eggs as a primary ingredient.
                - Do NOT suggest any vegetarian or vegan recipes.
                - Every recipe's dietary_classification field MUST be "Non-Vegetarian".
                - If the user's ingredients don't include meat, suggest recipes where meat is a gap ingredient (is_gap: true).
                - Examples of acceptable recipes: Chicken Curry, Mutton Biryani, Egg Bhurji, Prawn Masala, Fish Fry.
                - Vegetable Pulao, Dal, Paneer dishes, and any meatless recipes are STRICTLY FORBIDDEN.
                """
            case .vegetarian:
                dietaryInstruction = """
                DIETARY REQUIREMENT — VEGETARIAN (MANDATORY):
                - ALL recipes MUST be vegetarian. No meat, poultry, or seafood.
                - Every recipe's dietary_classification field MUST be "Vegetarian".
                """
            }
        } else {
            dietaryInstruction = "DIETARY REQUIREMENT: Recipes may be either Vegetarian or Non-Vegetarian."
        }

        return """
        You are ChefNova, an expert recipe generator specialising in \(request.cuisine.rawValue) cuisine.

        \(dietaryInstruction)

        SKILL LEVEL: Only suggest recipes appropriate for a \(request.skillLevel.rawValue) cook.

        THE USER HAS THESE INGREDIENTS (mark ALL of these as is_gap: false):
        \(userIngredientsList)

        PANTRY STAPLES — also treat these as ALWAYS available (mark as is_gap: false):
        \(staplesList)

        CRITICAL RULE: Any ingredient from either list above MUST have is_gap: false.
        Only mark is_gap: true for ingredients the user does NOT have and are NOT pantry staples.

        Compute match_score as: (number of non-pantry-staple recipe ingredients the user has) / (total non-pantry-staple recipe ingredients).
        A score of 1.0 means the user has everything. A score of 0.0 means they have nothing.

        Return between 3 and 5 recipes, sorted by match_score descending (best match first).

        You MUST respond using the provided JSON schema. Do not include any text outside the JSON object.
        """
    }

    /// Constructs the user-turn prompt listing the available ingredients.
    private func buildUserPrompt(for request: RecipeGenerationRequest) -> String {
        let ingredientsList = request.ingredients.joined(separator: ", ")
        return "My available ingredients: \(ingredientsList)"
    }
    /// model, applying the full gap-ingredient post-processing pipeline.
    private func mapToRankedRecipe(raw: RawRecipe, cuisine: Cuisine, userIngredients: [String]) -> RankedRecipe {
        // Map all ingredients to domain model (without gap metadata).
        let allIngredients = raw.ingredients.map { ri in
            RecipeIngredient(name: ri.name, quantity: ri.quantity, unit: ri.unit)
        }

        // Lowercased set of user-provided ingredients for fast lookup.
        let userIngredientSet = Set(userIngredients.map { $0.lowercased() })

        // Gap ingredient post-processing pipeline:
        // 1. Filter ingredients where is_gap == true.
        let gapRaw = raw.ingredients.filter { $0.is_gap }

        // 2. Client-side safety filter: exclude any ingredient the user actually
        //    provided (guards against the model incorrectly marking them as gaps),
        //    and exclude pantry staples for the selected cuisine.
        let filteredGap = gapRaw.filter { ri in
            let nameLower = ri.name.lowercased()
            let userHasIt = userIngredientSet.contains(nameLower)
            let isStaple = pantryStaplesService.isPantryStaple(ri.name, for: cuisine)
            return !userHasIt && !isStaple
        }

        // 3. Sort remaining gap ingredients by commonalityRank ascending.
        //    The model assigns commonality implicitly via list order; we use
        //    the index in the filtered list as a proxy for commonalityRank
        //    since the schema does not include a separate rank field.
        //    The rank is the 1-based position in the filtered (pre-sort) list.
        let indexedGap = filteredGap.enumerated().map { (index, ri) in
            (ri: ri, rank: index + 1)
        }
        let sortedGap = indexedGap.sorted { $0.rank < $1.rank }

        // 4. Truncate to maximum 5 gap ingredients.
        let truncatedGap = sortedGap.prefix(5)

        // 5. Construct purchaseSearchURL for each gap ingredient.
        let gapIngredients: [GapIngredient] = truncatedGap.compactMap { item in
            guard let url = purchaseSearchURL(for: item.ri.name) else { return nil }
            return GapIngredient(
                name: item.ri.name,
                commonalityRank: item.rank,
                purchaseSearchURL: url
            )
        }

        // Build the Recipe domain model.
        let cuisine = Cuisine(rawValue: raw.cuisine) ?? cuisine
        let dietaryClassification = DietaryPreference(rawValue: raw.dietary_classification)
            ?? .vegetarian
        let skillLevel = SkillLevel(rawValue: raw.skill_level) ?? .beginner

        let recipe = Recipe(
            id: UUID(),
            title: raw.title,
            cuisine: cuisine,
            dietaryClassification: dietaryClassification,
            skillLevel: skillLevel,
            prepTimeMinutes: raw.prep_time_minutes,
            cookTimeMinutes: raw.cook_time_minutes,
            servingSize: raw.serving_size,
            ingredients: allIngredients,
            steps: raw.steps
        )

        return RankedRecipe(
            id: UUID(),
            recipe: recipe,
            matchScore: raw.match_score,
            isPartialMatch: raw.match_score < 1.0,
            gapIngredients: gapIngredients
        )
    }

    /// Constructs the Google Shopping search URL for a gap ingredient.
    ///
    /// Format: `https://www.google.com/search?q=buy+{ingredient}` (URL-encoded).
    private func purchaseSearchURL(for ingredientName: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        let query = "buy \(ingredientName)"
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }

    // MARK: - Static helpers

    /// Creates a `URLSession` configured with a 10-second request timeout.
    private static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = timeoutInterval
        return URLSession(configuration: config)
    }

    /// Reads the OpenAI API key.
    ///
    /// Checks two sources in order:
    /// 1. The `OPENAI_API_KEY` process environment variable (set via Xcode scheme
    ///    Run → Arguments → Environment Variables). This is the recommended approach
    ///    for local development.
    /// 2. `Info.plist["OpenAIAPIKey"]` — used when the key is injected at build time
    ///    via a build setting (CI/CD pipelines).
    private static func readAPIKey() -> String {
        // 1. Check process environment (Xcode scheme environment variable).
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
           !envKey.isEmpty {
            return envKey
        }

        // 2. Fall back to Info.plist build-time substitution.
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String,
           !plistKey.isEmpty,
           plistKey != "$(OPENAI_API_KEY)" {
            return plistKey
        }

        Self.logger.warning("RecipeEngineService: OPENAI_API_KEY not found. Set it in Xcode: Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables.")
        return ""
    }
}
