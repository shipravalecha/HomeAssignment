# Implementation Plan: ChefNova iOS App

## Overview

Implement the ChefNova iOS app using SwiftUI + MVVM with `@Observable`, SwiftData for preference persistence, and the OpenAI Chat Completions API with structured outputs. The implementation proceeds layer by layer: project scaffolding → data models → services → view models → views → error handling → tests.

## Tasks

- [x] 1. Set up Xcode project, dependencies, and bundled data files
  - Create a new Xcode project targeting iOS 17+ with SwiftUI and Swift 6 concurrency enabled
  - Add SwiftCheck via Swift Package Manager (`https://github.com/typelift/SwiftCheck`)
  - Create `SynonymDictionary.json` in the app bundle with at least the synonym entries described in the design (onion variants, tomato variants, and a representative set of common ingredients)
  - Create `PantryStaples.json` in the app bundle with the North Indian staples list: Salt, Black Pepper, Red Chilli Powder, Turmeric, Cumin Seeds, Coriander Powder, Garam Masala, Oil
  - Add both JSON files to the app target so they are accessible via `Bundle.main`
  - Create the unit test target and UI test target; add SwiftCheck to the unit test target
  - _Requirements: 7.1, 10.1_

- [x] 2. Define core data models and enums
  - [x] 2.1 Implement enums and type aliases
    - Define `Cuisine`, `DietaryPreference`, and `SkillLevel` enums with `String`, `Codable`, and `CaseIterable` conformances as specified in the design
    - Define `typealias CanonicalIngredient = String`
    - _Requirements: 2.1, 2.2, 3.1_

  - [x] 2.2 Implement recipe domain models
    - Implement `RecipeIngredient`, `Recipe`, `RankedRecipe`, and `GapIngredient` structs with `Codable`, `Identifiable`, and `Equatable` conformances as specified in the design
    - Implement `RecipeGenerationRequest` struct
    - _Requirements: 4.4, 5.1, 6.2_

  - [x] 2.3 Implement SwiftData persistence model
    - Implement `@Model final class PreferenceProfile` with `cuisine`, `dietaryPreference`, `skillLevel`, and `savedAt` fields as specified in the design
    - _Requirements: 8.1, 8.3_

  - [x] 2.4 Implement error types
    - Implement `RecipeEngineError` enum with `timeout`, `networkUnavailable`, `serverError(statusCode:logMessage:)`, `noResultsFound`, and `invalidResponse` cases, conforming to `LocalizedError`
    - Implement `IngredientValidationError` enum with `unrecognized(rawName:)`, `emptyList`, and `allWhitespace` cases
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [x] 3. Implement IngredientNormalizerService
  - [x] 3.1 Define protocol and implement service
    - Define `IngredientNormalizerServiceProtocol` with `normalize(_:) -> String?` and `isRecognized(_:) -> Bool` methods
    - Implement `IngredientNormalizerService` that loads `SynonymDictionary.json` from `Bundle.main` once at init, performs case-insensitive whitespace-trimmed lookup, and returns `nil` for unrecognized inputs
    - _Requirements: 1.3, 1.4, 7.1, 7.2, 7.3_

  - [x] 3.2 Write property test: Normalizer Idempotence (Property 1)
    - **Property 1: Normalizer Idempotence** — for any canonical name in the dictionary, `normalize(normalize(x)) == normalize(x)`
    - **Validates: Requirements 7.4**

  - [x] 3.3 Write property test: Normalizer Round-Trip Stability (Property 2)
    - **Property 2: Normalizer Round-Trip Stability** — for any variant key in the synonym map, normalizing then re-normalizing returns the same canonical name
    - **Validates: Requirements 7.5, 1.3**

  - [x] 3.4 Write property test: Unrecognized Ingredient Returns Nil (Property 3)
    - **Property 3: Unrecognized Ingredient Returns Nil** — for any string not present in the synonym dictionary, `normalize` returns `nil`
    - **Validates: Requirements 1.4, 7.3**

  - [x] 3.5 Write property test: Whitespace-Only Ingredients Are Rejected (Property 4)
    - **Property 4: Whitespace-Only Ingredients Are Rejected** — for any string composed entirely of whitespace characters, `normalize` returns `nil`
    - **Validates: Requirements 9.5, 1.7**

  - [x] 3.6 Write unit tests for IngredientNormalizerService
    - Test specific synonym mappings (e.g., "onions" → "Onion", "tomatoes" → "Tomato")
    - Test case-insensitive lookup ("ONION", "Onion", "onion" all normalize to "Onion")
    - Test that an unrecognized string returns `nil`
    - Test that a whitespace-only string returns `nil`
    - _Requirements: 1.3, 1.4, 7.2, 7.3_

- [x] 4. Implement PantryStaplesService
  - [x] 4.1 Define protocol and implement service
    - Define `PantryStaplesServiceProtocol` with `getPantryStaples(for:) -> [String]` and `isPantryStaple(_:for:) -> Bool` methods
    - Implement `PantryStaplesService` that loads `PantryStaples.json` from `Bundle.main` once at init and performs case-insensitive comparisons
    - _Requirements: 10.1, 10.2, 10.3_

  - [x] 4.2 Write unit tests for PantryStaplesService
    - Test that `getPantryStaples(for: .northIndian)` returns all 8 expected staples
    - Test `isPantryStaple` boundary cases: known staple returns `true`, unknown ingredient returns `false`, case-insensitive match returns `true`
    - _Requirements: 10.1, 10.4_

- [x] 5. Implement PreferencePersistenceService
  - [x] 5.1 Define protocol and implement service
    - Define `PreferencePersistenceServiceProtocol` with `savePreferences(_:) throws` and `loadLatestPreferences() -> PreferenceProfile?` methods
    - Implement `PreferencePersistenceService` using SwiftData `ModelContext`; `savePreferences` inserts or updates the profile and calls `context.save()`; `loadLatestPreferences` fetches the most recently saved profile sorted by `savedAt` descending
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

  - [x] 5.2 Write property test: Preference Profile Round-Trip (Property 9)
    - **Property 9: Preference Profile Round-Trip** — for any valid combination of `Cuisine`, `DietaryPreference?`, and `SkillLevel`, saving then loading returns equal values
    - Use an in-memory SwiftData container for isolation
    - **Validates: Requirements 2.5, 3.6, 8.1, 8.2, 8.4**

  - [x] 5.3 Write unit tests for PreferencePersistenceService
    - Test save-then-load round-trip with a concrete profile
    - Test that saving a second profile overwrites and `loadLatestPreferences` returns the newer values
    - Use an in-memory SwiftData container
    - _Requirements: 8.1, 8.2, 8.4_

- [x] 6. Checkpoint — Ensure all tests pass
  - Run the full test suite; confirm all service-layer unit and property tests pass. Ask the user if any questions arise before proceeding.

- [x] 7. Implement RecipeEngineService
  - [x] 7.1 Define protocol and implement service skeleton
    - Define `RecipeEngineServiceProtocol` with `generateRecipes(request:) async throws -> [RankedRecipe]`
    - Implement `RecipeEngineService` with a `URLSession` dependency (injectable for testing); store the OpenAI API key via a configuration mechanism (e.g., `Info.plist` key or environment variable — never hardcoded)
    - _Requirements: 4.1, 4.2, 4.3_

  - [x] 7.2 Implement prompt construction and JSON schema
    - Implement the system prompt that instructs the model to act as a recipe generator, treat pantry staples as implicitly available, and return results in the defined JSON schema
    - Embed the `RecipeEngineResponseSchema` JSON schema in the `response_format` field of the request body as specified in the design
    - _Requirements: 4.1, 10.2_

  - [x] 7.3 Implement response parsing and gap ingredient post-processing
    - Decode the OpenAI structured output JSON into `[RankedRecipe]`
    - Implement gap ingredient post-processing: filter `is_gap == true` ingredients, exclude pantry staples for the selected cuisine, sort by `commonalityRank` ascending, truncate to 5, construct `purchaseSearchURL` as `https://www.google.com/search?q=buy+{ingredient}`
    - _Requirements: 4.1, 5.1, 5.2, 5.3, 5.4, 10.4_

  - [x] 7.4 Implement error mapping and timeout
    - Apply a 10-second `URLSession` timeout; throw `RecipeEngineError.timeout` on expiry
    - Map HTTP 5xx responses to `RecipeEngineError.serverError`; log using `os.Logger` with status code and sanitized request identifier (no PII)
    - Map network unavailability to `RecipeEngineError.networkUnavailable`
    - Map empty results array to `RecipeEngineError.noResultsFound`
    - _Requirements: 9.2, 9.3, 9.4_

  - [x] 7.5 Write property test: Match Score Ordering (Property 5)
    - **Property 5: Match Score Ordering** — for any list of `RankedRecipe` values produced by the post-processing pipeline, the list is sorted by `matchScore` descending (no recipe appears before one with a strictly higher score)
    - **Validates: Requirements 4.1**

  - [x] 7.6 Write property test: Pantry Staples Excluded from Gap Ingredients (Property 6)
    - **Property 6: Pantry Staples Excluded from Gap Ingredients** — for any partial match recipe and any cuisine, no ingredient in the pantry staples list for that cuisine appears in the gap ingredients list
    - **Validates: Requirements 5.1, 10.4**

  - [x] 7.7 Write property test: Gap Ingredient Processing Invariants (Property 7)
    - **Property 7: Gap Ingredient Processing Invariants** — for any raw gap ingredient list: (a) displayed list has ≤ 5 entries, (b) entries are ordered by `commonalityRank` ascending, (c) every entry has a non-nil `purchaseSearchURL`
    - **Validates: Requirements 5.2, 5.3, 5.4**

  - [x] 7.8 Write property test: Pantry Staples Included in Recipe Generation Request (Property 10)
    - **Property 10: Pantry Staples Included in Recipe Generation Request** — for any selected cuisine, the `RecipeGenerationRequest` constructed for that cuisine includes all pantry staples for that cuisine in its `pantryStaples` field
    - **Validates: Requirements 10.2**

  - [x] 7.9 Write unit tests for RecipeEngineService
    - Use a mock `URLSession` (or `URLProtocol` stub) to simulate: valid structured response, timeout, HTTP 500, network error, empty `recipes` array
    - Verify correct `RankedRecipe` values are returned for a valid response
    - Verify correct error types are thrown for each failure scenario
    - _Requirements: 4.1, 4.2, 9.2, 9.3, 9.4_

- [x] 8. Implement RecipeDetailViewModel
  - [x] 8.1 Implement serving size adjustment logic
    - Implement `RecipeDetailViewModel` with `@Observable`; hold the selected `RankedRecipe` and a `targetServings: Int` property (initialized to `recipe.servingSize`)
    - Implement `adjustedQuantity(original:originalServings:targetServings:) -> Double` pure function as specified in the design
    - Expose `adjustedIngredients: [RecipeIngredient]` computed property that applies `adjustedQuantity` to every ingredient
    - _Requirements: 6.2, 6.3_

  - [x] 8.2 Write property test: Serving Size Proportional Scaling (Property 8)
    - **Property 8: Serving Size Proportional Scaling** — for any recipe with positive original serving size and any positive target serving size, every adjusted quantity equals `original * (targetServings / originalServings)`
    - **Validates: Requirements 6.3**

  - [x] 8.3 Write unit tests for RecipeDetailViewModel
    - Test `adjustedQuantity` with integer quantities, fractional quantities, and the edge case where `targetServings == originalServings`
    - Test that `adjustedIngredients` reflects the correct scaled values
    - _Requirements: 6.3_

- [x] 9. Implement IngredientInputViewModel and PreferenceViewModel
  - [x] 9.1 Implement IngredientInputViewModel
    - Implement `IngredientInputViewModel` with `@Observable`; hold `ingredients: [CanonicalIngredient]`, `rawInput: String`, and `validationError: IngredientValidationError?`
    - Implement `addIngredient()`: call `IngredientNormalizerService.normalize(rawInput)`; if `nil`, set `validationError = .unrecognized(rawName:)`; otherwise append to `ingredients` and clear `rawInput`
    - Implement `removeIngredient(at:)` to remove by index
    - Implement `validateForSubmission() -> Bool`: return `false` and set `validationError = .emptyList` if `ingredients` is empty
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7_

  - [x] 9.2 Implement PreferenceViewModel
    - Implement `PreferenceViewModel` with `@Observable`; hold `selectedCuisine: Cuisine?`, `selectedDietaryPreference: DietaryPreference?`, `selectedSkillLevel: SkillLevel` (default `.beginner`)
    - On init, call `PreferencePersistenceService.loadLatestPreferences()` and pre-populate selectors if a profile exists
    - Implement `savePreferences()` that calls `PreferencePersistenceService.savePreferences` with current selections
    - Implement `validateForSubmission() -> Bool`: return `false` if `selectedCuisine == nil`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.5, 3.6, 8.1, 8.2_

  - [x] 9.3 Write unit tests for IngredientInputViewModel
    - Test that adding a recognized ingredient appends to the list and clears `rawInput`
    - Test that adding an unrecognized ingredient sets `validationError` and does not modify the list
    - Test that `removeIngredient(at:)` removes the correct entry
    - Test that `validateForSubmission()` returns `false` with an empty list and `true` with at least one ingredient
    - _Requirements: 1.2, 1.4, 1.5, 1.7_

  - [x] 9.4 Write unit tests for PreferenceViewModel
    - Test that pre-population occurs when a saved profile exists
    - Test that `validateForSubmission()` returns `false` when no cuisine is selected
    - Test that `savePreferences()` persists the current selections
    - _Requirements: 2.3, 2.5, 3.6, 8.1_

- [x] 10. Implement RecipeResultsViewModel
  - [x] 10.1 Implement recipe generation orchestration
    - Implement `RecipeResultsViewModel` with `@Observable`; hold `state: LoadingState` (enum: `idle`, `loading`, `results([RankedRecipe])`, `error(RecipeEngineError)`)
    - Implement `generateRecipes(ingredients:preferences:)` async method: fetch pantry staples via `PantryStaplesService`, build `RecipeGenerationRequest`, call `RecipeEngineService.generateRecipes`, update `state` accordingly
    - After successful generation, call `PreferencePersistenceService.savePreferences` with the used preferences
    - _Requirements: 4.1, 4.2, 4.3, 4.5, 8.1_

  - [x] 10.2 Implement network monitoring
    - Integrate `NWPathMonitor` (from `Network.framework`) into `RecipeResultsViewModel`; expose `isNetworkAvailable: Bool`
    - Disable the retry button when `isNetworkAvailable == false`; re-enable automatically when connectivity is restored
    - _Requirements: 9.3_

  - [x] 10.3 Write unit tests for RecipeResultsViewModel
    - Test that `state` transitions to `.loading` then `.results` on a successful generation
    - Test that `state` transitions to `.error(.timeout)` when the service throws `RecipeEngineError.timeout`
    - Test that `state` transitions to `.error(.networkUnavailable)` when the service throws `RecipeEngineError.networkUnavailable`
    - Use mock service implementations
    - _Requirements: 4.1, 9.2, 9.3_

- [x] 11. Checkpoint — Ensure all tests pass
  - Run the full test suite; confirm all ViewModel and service tests pass. Ask the user if any questions arise before proceeding.

- [x] 12. Implement IngredientInputView and PreferenceSelectionView
  - [x] 12.1 Implement IngredientInputView
    - Build `IngredientInputView` in SwiftUI; bind to `IngredientInputViewModel`
    - Include a `TextField` for `rawInput`, an "Add" button that calls `addIngredient()`, and a `List` displaying `ingredients` with swipe-to-delete calling `removeIngredient(at:)`
    - Display inline validation error text when `validationError` is non-nil
    - Include a "Generate Recipes" button that calls `validateForSubmission()` before navigating
    - _Requirements: 1.1, 1.2, 1.4, 1.5, 1.6, 1.7_

  - [x] 12.2 Implement PreferenceSelectionView
    - Build `PreferenceSelectionView` in SwiftUI; bind to `PreferenceViewModel`
    - Include a `Picker` for `Cuisine` (required), a `Picker` for `DietaryPreference` (optional, with a "No Preference" option), and a `Picker` for `SkillLevel`
    - Display inline validation error when cuisine is not selected and the user attempts to proceed
    - Pre-populate pickers from `PreferenceViewModel` on appear
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.5, 3.6_

- [x] 13. Implement RecipeResultsView
  - Build `RecipeResultsView` in SwiftUI; bind to `RecipeResultsViewModel`
  - Show a `ProgressView` while `state == .loading`
  - Show a `List` of recipe cards when `state == .results`; each card displays title, match score (formatted as percentage), total time (prep + cook), serving size, and skill level
  - For partial match recipes, display gap ingredients inline on the card with purchase search links (`Link` view opening `purchaseSearchURL`)
  - Optionally display a pantry staples assumption notice (Requirement 10.5)
  - Show error banners with appropriate user-facing messages and a retry button for `.error` states; disable retry when `isNetworkAvailable == false`
  - Show the no-results message when `state == .error(.noResultsFound)`
  - _Requirements: 4.4, 4.5, 4.6, 5.1, 5.2, 5.3, 5.4, 9.2, 9.3, 9.4, 10.5_

- [x] 14. Implement RecipeDetailView
  - Build `RecipeDetailView` in SwiftUI; bind to `RecipeDetailViewModel`
  - Display recipe title, cuisine, dietary classification, skill level, total time, and serving size
  - Display a `Stepper` for `targetServings` (minimum 1); bind to `RecipeDetailViewModel.targetServings`
  - Display `adjustedIngredients` with quantity and unit; quantities update reactively as `targetServings` changes
  - Display numbered cooking steps
  - For partial match recipes, display a clearly distinguished "Gap Ingredients" section listing gap ingredients with purchase search links
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 15. Wire navigation and app entry point
  - [x] 15.1 Implement app entry point and SwiftData container
    - Implement the `@main App` struct; configure the SwiftData `ModelContainer` with `PreferenceProfile` and inject it into the environment
    - Instantiate and inject all services (normalizer, pantry staples, recipe engine, persistence) as environment objects or via dependency injection into view models
    - _Requirements: 8.3_

  - [x] 15.2 Implement NavigationStack flow
    - Wire `NavigationStack` so the app flows: `IngredientInputView` → `PreferenceSelectionView` → `RecipeResultsView` → `RecipeDetailView` (on recipe tap)
    - Pass `IngredientInputViewModel` ingredients and `PreferenceViewModel` selections into `RecipeResultsViewModel.generateRecipes` when the user confirms on `PreferenceSelectionView`
    - _Requirements: 4.1, 6.1_

- [x] 16. Checkpoint — Build the app and ensure it compiles and runs on the iOS Simulator
  - Resolve any compiler errors or warnings. Ask the user if any questions arise before proceeding.

- [x] 17. Write UI tests (XCUITest)
  - [x] 17.1 Write UI test: Ingredient input flow
    - Test adding a recognized ingredient, verifying it appears in the list
    - Test attempting to submit with an empty list and verifying the error message appears
    - Test removing an ingredient from the list
    - _Requirements: 1.1, 1.5, 1.7_

  - [x] 17.2 Write UI test: Preference selection flow
    - Test that attempting to proceed without selecting a cuisine shows the validation error
    - Test that dietary preference selection is optional (can proceed without it)
    - _Requirements: 2.3, 2.4_

  - [x] 17.3 Write UI test: Recipe results list
    - Using a mock or stubbed `RecipeEngineService`, verify that recipe cards render with title, match score, time, and skill level
    - _Requirements: 4.4_

  - [x] 17.4 Write UI test: Recipe detail serving size adjustment
    - Navigate to a recipe detail view and interact with the serving size stepper; verify that displayed ingredient quantities update proportionally
    - _Requirements: 6.3_

  - [x] 17.5 Write UI test: Error state — network error banner and retry button
    - Simulate a network error and verify the error banner appears and the retry button is present
    - _Requirements: 9.3_

- [x] 18. Final checkpoint — Ensure all tests pass
  - Run the complete test suite (unit, property-based, and UI tests). Confirm everything passes. Ask the user if any questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements for traceability
- Property tests use SwiftCheck and run a minimum of 100 iterations each
- Property tests are placed close to the implementation tasks they validate to catch errors early
- Checkpoints ensure incremental validation at each major layer boundary
- The OpenAI API key must never be hardcoded; use `Info.plist` or an environment variable
- All service protocols enable dependency injection for testability
- SwiftData operations in tests use an in-memory `ModelContainer` for isolation
