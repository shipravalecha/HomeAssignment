import XCTest

final class ChefNovaUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        // Verify the app launches without crashing.
        XCTAssertTrue(app.exists)
    }

    // MARK: - Ingredient Input Flow Tests

    /// Test adding a recognized ingredient verifies it appears in the list.
    /// Validates: Requirements 1.1, 1.2, 1.3
    @MainActor
    func testAddRecognizedIngredientAppearsInList() throws {
        let app = XCUIApplication()
        app.launch()

        // Locate the ingredient text field and type a recognized ingredient
        let textField = app.textFields["ingredientTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "Ingredient text field should exist")
        textField.tap()
        textField.typeText("Onion")

        // Tap the Add button
        let addButton = app.buttons["addIngredientButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Add button should exist")
        addButton.tap()

        // Verify "Onion" appears in the list
        let onionCell = app.staticTexts["Onion"]
        XCTAssertTrue(onionCell.waitForExistence(timeout: 3), "Onion should appear in the ingredient list after being added")
    }

    /// Test attempting to submit with an empty list shows the error message.
    /// Validates: Requirements 1.7
    @MainActor
    func testSubmitWithEmptyListShowsErrorMessage() throws {
        let app = XCUIApplication()
        app.launch()

        // Tap "Generate Recipes" without adding any ingredients
        let generateButton = app.buttons["generateRecipesButton"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 5), "Generate Recipes button should exist")
        generateButton.tap()

        // Verify the validation error message appears
        let errorText = app.staticTexts["validationErrorText"]
        XCTAssertTrue(errorText.waitForExistence(timeout: 3), "Validation error message should appear when submitting with empty list")
        XCTAssertTrue(
            errorText.label.contains("Please add at least one ingredient"),
            "Error message should prompt user to add at least one ingredient, got: \(errorText.label)"
        )
    }

    // MARK: - Preference Selection Flow Tests

    /// Helper: navigate to PreferenceSelectionView by adding "Onion" and tapping "Generate Recipes".
    @MainActor
    private func navigateToPreferenceSelectionView(app: XCUIApplication) {
        let textField = app.textFields["ingredientTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "Ingredient text field should exist")
        textField.tap()
        textField.typeText("Onion")

        let addButton = app.buttons["addIngredientButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Add button should exist")
        addButton.tap()

        let generateButton = app.buttons["generateRecipesButton"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 3), "Generate Recipes button should exist")
        generateButton.tap()

        // Wait for the Preferences screen to appear
        let findRecipesButton = app.buttons["findRecipesButton"]
        XCTAssertTrue(findRecipesButton.waitForExistence(timeout: 5), "Find Recipes button should appear on Preferences screen")
    }

    /// Test that tapping "Find Recipes" without selecting a cuisine shows the validation error.
    /// Validates: Requirements 2.3
    @MainActor
    func testProceedWithoutCuisineShowsValidationError() throws {
        let app = XCUIApplication()
        app.launch()

        navigateToPreferenceSelectionView(app: app)

        // Tap "Find Recipes" without selecting a cuisine
        let findRecipesButton = app.buttons["findRecipesButton"]
        findRecipesButton.tap()

        // Verify the validation error appears
        let errorText = app.staticTexts["preferenceValidationErrorText"]
        XCTAssertTrue(
            errorText.waitForExistence(timeout: 3),
            "Validation error should appear when attempting to proceed without selecting a cuisine"
        )
        XCTAssertTrue(
            errorText.label.contains("Please select a cuisine"),
            "Error message should prompt user to select a cuisine, got: \(errorText.label)"
        )
    }

    /// Test that dietary preference selection is optional — user can proceed with only a cuisine selected.
    /// Validates: Requirements 2.4
    @MainActor
    func testDietaryPreferenceIsOptional() throws {
        let app = XCUIApplication()
        app.launch()

        navigateToPreferenceSelectionView(app: app)

        // Select a cuisine using the picker (Form picker navigates to a selection list)
        let cuisinePicker = app.buttons["cuisinePicker"]
        XCTAssertTrue(cuisinePicker.waitForExistence(timeout: 3), "Cuisine picker should exist")
        cuisinePicker.tap()

        // The picker pushes a selection list — tap "North Indian"
        let northIndianOption = app.staticTexts["North Indian"]
        XCTAssertTrue(
            northIndianOption.waitForExistence(timeout: 3),
            "North Indian option should appear in the cuisine picker list"
        )
        northIndianOption.tap()

        // After selection the picker auto-navigates back to the Preferences form.
        // Wait for the Find Recipes button to be visible again.
        let findRecipesButton = app.buttons["findRecipesButton"]
        XCTAssertTrue(findRecipesButton.waitForExistence(timeout: 3), "Find Recipes button should be visible after cuisine selection")

        // Do NOT select a dietary preference — leave it at "No Preference"

        // Tap "Find Recipes"
        findRecipesButton.tap()

        // Verify no validation error appears (dietary preference is optional)
        let errorText = app.staticTexts["preferenceValidationErrorText"]
        XCTAssertFalse(
            errorText.exists,
            "No validation error should appear when dietary preference is not selected"
        )

        // Verify navigation proceeds to the recipe results screen
        let recipesNavTitle = app.navigationBars["Recipes"]
        XCTAssertTrue(
            recipesNavTitle.waitForExistence(timeout: 5),
            "Should navigate to the Recipes screen when cuisine is selected but dietary preference is not"
        )
    }

    /// Test removing an ingredient from the list via swipe-to-delete.
    /// Validates: Requirements 1.5
    @MainActor
    func testRemoveIngredientFromList() throws {
        let app = XCUIApplication()
        app.launch()

        // First add "Onion" to the list
        let textField = app.textFields["ingredientTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "Ingredient text field should exist")
        textField.tap()
        textField.typeText("Onion")

        let addButton = app.buttons["addIngredientButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Add button should exist")
        addButton.tap()

        // Verify "Onion" is in the list
        let onionCell = app.staticTexts["Onion"]
        XCTAssertTrue(onionCell.waitForExistence(timeout: 3), "Onion should appear in the list before deletion")

        // Swipe left on the Onion cell to reveal the delete action
        onionCell.swipeLeft()

        // Tap the Delete button that appears after swiping
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Delete button should appear after swiping left")
        deleteButton.tap()

        // Verify "Onion" is no longer in the list
        XCTAssertFalse(
            app.staticTexts["Onion"].exists,
            "Onion should be removed from the ingredient list after deletion"
        )
    }

    // MARK: - Recipe Results List Tests

    /// Helper: navigate all the way to the RecipeResultsView using the mock
    /// recipe engine (requires the app to be launched with "--uitesting").
    ///
    /// Flow: add "Onion" → tap Generate Recipes → select North Indian cuisine
    ///       → tap Find Recipes → wait for Recipes nav bar.
    @MainActor
    private func navigateToRecipeResultsView(app: XCUIApplication) {
        // Step 1: Add a recognized ingredient
        let textField = app.textFields["ingredientTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "Ingredient text field should exist")
        textField.tap()
        textField.typeText("Onion")

        let addButton = app.buttons["addIngredientButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Add button should exist")
        addButton.tap()

        // Step 2: Navigate to Preferences
        let generateButton = app.buttons["generateRecipesButton"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 3), "Generate Recipes button should exist")
        generateButton.tap()

        // Step 3: Select North Indian cuisine.
        // In a SwiftUI Form, a Picker may render as a menu button or navigation link.
        // Try tapping the picker button and then selecting from the menu or list.
        let cuisinePickerButton = app.buttons["cuisinePicker"]
        if cuisinePickerButton.exists {
            cuisinePickerButton.tap()
        }

        // Wait briefly for the menu or list to appear.
        Thread.sleep(forTimeInterval: 0.5)

        // Try menu item first (for .menu style pickers)
        let northIndianMenuItem = app.buttons["North Indian"]
        let northIndianStaticText = app.staticTexts["North Indian"]

        if northIndianMenuItem.waitForExistence(timeout: 2) {
            northIndianMenuItem.tap()
        } else if northIndianStaticText.waitForExistence(timeout: 2) {
            northIndianStaticText.tap()
        } else {
            // The picker might be using a different interaction model.
            // Try tapping the cell that contains "Cuisine" text.
            let cuisineCell = app.cells.containing(.staticText, identifier: "Cuisine").firstMatch
            if cuisineCell.exists {
                cuisineCell.tap()
                Thread.sleep(forTimeInterval: 0.5)
                if northIndianStaticText.waitForExistence(timeout: 2) {
                    northIndianStaticText.tap()
                } else if northIndianMenuItem.waitForExistence(timeout: 2) {
                    northIndianMenuItem.tap()
                }
            }
        }

        // Step 4: Tap Find Recipes (wait for it to be visible after cuisine selection)
        // Add a brief pause to allow the picker selection to propagate back to the form.
        Thread.sleep(forTimeInterval: 1.0)
        // Scroll down to ensure the Find Recipes button is visible.
        app.swipeUp()
        let findRecipesButton = app.buttons["findRecipesButton"]
        XCTAssertTrue(findRecipesButton.waitForExistence(timeout: 5), "Find Recipes button should be visible after cuisine selection")
        findRecipesButton.tap()

        // Step 5: Wait for the Recipes navigation bar
        let recipesNavBar = app.navigationBars["Recipes"]
        XCTAssertTrue(recipesNavBar.waitForExistence(timeout: 10), "Should navigate to the Recipes screen")
    }

    /// Verify that recipe cards render with title, match score, time, and skill level.
    ///
    /// Uses the mock RecipeEngineService (injected via "--uitesting" launch argument)
    /// which returns three deterministic recipes: Aloo Gobi (100%), Palak Paneer (75%),
    /// and Dal Makhani (50%).
    ///
    /// Validates: Requirements 4.4
    @MainActor
    func testRecipeResultsListRendersCardElements() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        navigateToRecipeResultsView(app: app)

        // Wait for the recipe list to load (mock has a 0.3 s delay)
        // The first recipe card title should appear within a reasonable timeout.
        let firstRecipeTitle = app.staticTexts["Aloo Gobi"]
        XCTAssertTrue(
            firstRecipeTitle.waitForExistence(timeout: 10),
            "First recipe title 'Aloo Gobi' should appear in the results list"
        )

        // --- Verify Aloo Gobi card (full match, 100%) ---

        // Title
        XCTAssertTrue(
            app.staticTexts["Aloo Gobi"].exists,
            "Recipe card should display the recipe title 'Aloo Gobi'"
        )

        // Match score (100%)
        XCTAssertTrue(
            app.staticTexts["100%"].exists,
            "Recipe card should display the match score as a percentage (100%)"
        )

        // Total time: prep 10 + cook 20 = 30 min
        XCTAssertTrue(
            app.staticTexts["30 min"].exists,
            "Recipe card should display the total time (prep + cook) as '30 min'"
        )

        // Skill level
        XCTAssertTrue(
            app.staticTexts["Beginner"].exists,
            "Recipe card should display the skill level 'Beginner'"
        )

        // --- Verify Palak Paneer card (partial match, 75%) ---

        XCTAssertTrue(
            app.staticTexts["Palak Paneer"].exists,
            "Second recipe title 'Palak Paneer' should appear in the results list"
        )

        // Match score (75%)
        XCTAssertTrue(
            app.staticTexts["75%"].exists,
            "Recipe card should display the match score as a percentage (75%)"
        )

        // Total time: prep 15 + cook 25 = 40 min
        XCTAssertTrue(
            app.staticTexts["40 min"].exists,
            "Recipe card should display the total time (prep + cook) as '40 min'"
        )

        // --- Verify Dal Makhani card (partial match, 50%) ---

        XCTAssertTrue(
            app.staticTexts["Dal Makhani"].exists,
            "Third recipe title 'Dal Makhani' should appear in the results list"
        )

        // Match score (50%)
        XCTAssertTrue(
            app.staticTexts["50%"].exists,
            "Recipe card should display the match score as a percentage (50%)"
        )

        // Total time: prep 20 + cook 40 = 60 min
        XCTAssertTrue(
            app.staticTexts["60 min"].exists,
            "Recipe card should display the total time (prep + cook) as '60 min'"
        )

        // Skill level for Dal Makhani
        XCTAssertTrue(
            app.staticTexts["Intermediate/Pro"].exists,
            "Recipe card should display the skill level 'Intermediate/Pro' for Dal Makhani"
        )
    }

    /// Verify that all three recipe cards are present in the results list.
    ///
    /// Validates: Requirements 4.4
    @MainActor
    func testRecipeResultsListShowsMultipleCards() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        navigateToRecipeResultsView(app: app)

        // Wait for results to load
        XCTAssertTrue(
            app.staticTexts["Aloo Gobi"].waitForExistence(timeout: 10),
            "Recipe results should load within timeout"
        )

        // All three mock recipes should be visible
        XCTAssertTrue(app.staticTexts["Aloo Gobi"].exists, "Aloo Gobi should be in the results list")
        XCTAssertTrue(app.staticTexts["Palak Paneer"].exists, "Palak Paneer should be in the results list")
        XCTAssertTrue(app.staticTexts["Dal Makhani"].exists, "Dal Makhani should be in the results list")
    }

    // MARK: - Recipe Detail Serving Size Tests

    /// Helper: navigate all the way to the Aloo Gobi RecipeDetailView using the
    /// mock recipe engine (requires the app to be launched with "--uitesting").
    ///
    /// Flow: add "Onion" → tap Generate Recipes → select North Indian cuisine
    ///       → tap Find Recipes → wait for Recipes nav bar → tap "Aloo Gobi" card.
    @MainActor
    private func navigateToAlooGobiDetailView(app: XCUIApplication) {
        navigateToRecipeResultsView(app: app)

        // Wait for the Aloo Gobi recipe card to appear
        let alooGobiCard = app.staticTexts["Aloo Gobi"]
        XCTAssertTrue(
            alooGobiCard.waitForExistence(timeout: 10),
            "Aloo Gobi recipe card should appear in the results list"
        )

        // Tap the Aloo Gobi card to navigate to the detail view
        alooGobiCard.tap()

        // Wait for the detail view navigation title "Aloo Gobi" to appear
        let detailNavBar = app.navigationBars["Aloo Gobi"]
        XCTAssertTrue(
            detailNavBar.waitForExistence(timeout: 5),
            "Should navigate to the Aloo Gobi detail view"
        )
    }

    /// Verify that the serving size stepper in RecipeDetailView adjusts ingredient
    /// quantities proportionally when the serving size is increased.
    ///
    /// Aloo Gobi has servingSize=2, Potato=2 pieces, Cauliflower=1 head.
    /// Increasing to 4 servings should show Potato=4 pieces, Cauliflower=2 heads.
    ///
    /// Validates: Requirements 6.3
    @MainActor
    func testRecipeDetailServingSizeAdjustment() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        navigateToAlooGobiDetailView(app: app)

        // --- Verify initial state (servingSize = 2) ---

        // The stepper label should show "Servings: 2"
        let servingsStepper = app.steppers["servingsStepper"]
        XCTAssertTrue(
            servingsStepper.waitForExistence(timeout: 5),
            "Servings stepper should be present in the detail view"
        )

        // Verify initial ingredient quantities at 2 servings:
        // Potato: 2 pieces, Cauliflower: 1 head
        let potatoQuantityInitial = app.staticTexts["ingredientQuantity_Potato"]
        XCTAssertTrue(
            potatoQuantityInitial.waitForExistence(timeout: 3),
            "Potato quantity label should exist"
        )
        XCTAssertEqual(
            potatoQuantityInitial.label,
            "2 pieces",
            "Potato should show '2 pieces' at the original serving size of 2"
        )

        let cauliflowerQuantityInitial = app.staticTexts["ingredientQuantity_Cauliflower"]
        XCTAssertTrue(
            cauliflowerQuantityInitial.waitForExistence(timeout: 3),
            "Cauliflower quantity label should exist"
        )
        XCTAssertEqual(
            cauliflowerQuantityInitial.label,
            "1 head",
            "Cauliflower should show '1 head' at the original serving size of 2"
        )

        // --- Increase serving size from 2 to 4 (tap increment twice) ---

        // The Stepper's increment button is the "+" button within the stepper
        let incrementButton = servingsStepper.buttons["Increment"]
        XCTAssertTrue(
            incrementButton.waitForExistence(timeout: 3),
            "Stepper increment button should exist"
        )

        // Tap increment twice: 2 → 3 → 4
        incrementButton.tap()
        incrementButton.tap()

        // --- Verify updated quantities at 4 servings ---
        // Potato: 2 * (4/2) = 4 pieces
        // Cauliflower: 1 * (4/2) = 2 heads

        let potatoQuantityUpdated = app.staticTexts["ingredientQuantity_Potato"]
        XCTAssertTrue(
            potatoQuantityUpdated.waitForExistence(timeout: 3),
            "Potato quantity label should still exist after serving size change"
        )
        XCTAssertEqual(
            potatoQuantityUpdated.label,
            "4 pieces",
            "Potato should show '4 pieces' when serving size is increased to 4"
        )

        let cauliflowerQuantityUpdated = app.staticTexts["ingredientQuantity_Cauliflower"]
        XCTAssertTrue(
            cauliflowerQuantityUpdated.waitForExistence(timeout: 3),
            "Cauliflower quantity label should still exist after serving size change"
        )
        XCTAssertEqual(
            cauliflowerQuantityUpdated.label,
            "2 head",
            "Cauliflower should show '2 head' when serving size is increased to 4"
        )
    }

    /// Verify that the serving size stepper correctly decrements ingredient quantities.
    ///
    /// Aloo Gobi has servingSize=2, Potato=2 pieces, Cauliflower=1 head.
    /// Decreasing to 1 serving should show Potato=1 piece, Cauliflower=0.5 head.
    ///
    /// Validates: Requirements 6.3
    @MainActor
    func testRecipeDetailServingSizeDecrement() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        navigateToAlooGobiDetailView(app: app)

        // Locate the stepper
        let servingsStepper = app.steppers["servingsStepper"]
        XCTAssertTrue(
            servingsStepper.waitForExistence(timeout: 5),
            "Servings stepper should be present in the detail view"
        )

        // Tap decrement once: 2 → 1
        let decrementButton = servingsStepper.buttons["Decrement"]
        XCTAssertTrue(
            decrementButton.waitForExistence(timeout: 3),
            "Stepper decrement button should exist"
        )
        decrementButton.tap()

        // Verify updated quantities at 1 serving:
        // Potato: 2 * (1/2) = 1 piece
        // Cauliflower: 1 * (1/2) = 0.5 head

        let potatoQuantity = app.staticTexts["ingredientQuantity_Potato"]
        XCTAssertTrue(
            potatoQuantity.waitForExistence(timeout: 3),
            "Potato quantity label should exist after decrement"
        )
        XCTAssertEqual(
            potatoQuantity.label,
            "1 pieces",
            "Potato should show '1 pieces' when serving size is decreased to 1"
        )

        let cauliflowerQuantity = app.staticTexts["ingredientQuantity_Cauliflower"]
        XCTAssertTrue(
            cauliflowerQuantity.waitForExistence(timeout: 3),
            "Cauliflower quantity label should exist after decrement"
        )
        XCTAssertEqual(
            cauliflowerQuantity.label,
            "0.5 head",
            "Cauliflower should show '0.5 head' when serving size is decreased to 1"
        )
    }

    /// Verify that the pantry staples notice is displayed in the results list.
    ///
    /// Validates: Requirements 10.5
    @MainActor
    func testRecipeResultsListShowsPantryStaplesNotice() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        navigateToRecipeResultsView(app: app)

        // Wait for results to load
        XCTAssertTrue(
            app.staticTexts["Aloo Gobi"].waitForExistence(timeout: 10),
            "Recipe results should load within timeout"
        )

        // The pantry staples notice should be visible
        let noticeText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'pantry staples'")
        ).firstMatch
        XCTAssertTrue(
            noticeText.exists,
            "Pantry staples assumption notice should be displayed in the results list"
        )
    }

    // MARK: - Error State Tests

    /// Helper: navigate to RecipeResultsView using the network-error mock.
    ///
    /// The app is launched with "--uitesting-network-error" so the mock
    /// RecipeEngineService throws `RecipeEngineError.networkUnavailable`.
    /// The flow is identical to `navigateToRecipeResultsView` but uses the
    /// error-inducing launch argument.
    @MainActor
    private func navigateToRecipeResultsViewWithNetworkError(app: XCUIApplication) {
        // Step 1: Add a recognized ingredient
        let textField = app.textFields["ingredientTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "Ingredient text field should exist")
        textField.tap()
        textField.typeText("Onion")

        let addButton = app.buttons["addIngredientButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Add button should exist")
        addButton.tap()

        // Step 2: Navigate to Preferences
        let generateButton = app.buttons["generateRecipesButton"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 3), "Generate Recipes button should exist")
        generateButton.tap()

        // Step 3: Select North Indian cuisine
        let cuisinePickerButton = app.buttons["cuisinePicker"]
        if cuisinePickerButton.exists {
            cuisinePickerButton.tap()
        }

        Thread.sleep(forTimeInterval: 0.5)

        let northIndianMenuItem = app.buttons["North Indian"]
        let northIndianStaticText = app.staticTexts["North Indian"]

        if northIndianMenuItem.waitForExistence(timeout: 2) {
            northIndianMenuItem.tap()
        } else if northIndianStaticText.waitForExistence(timeout: 2) {
            northIndianStaticText.tap()
        } else {
            let cuisineCell = app.cells.containing(.staticText, identifier: "Cuisine").firstMatch
            if cuisineCell.exists {
                cuisineCell.tap()
                Thread.sleep(forTimeInterval: 0.5)
                if northIndianStaticText.waitForExistence(timeout: 2) {
                    northIndianStaticText.tap()
                } else if northIndianMenuItem.waitForExistence(timeout: 2) {
                    northIndianMenuItem.tap()
                }
            }
        }

        // Step 4: Tap Find Recipes
        Thread.sleep(forTimeInterval: 1.0)
        app.swipeUp()
        let findRecipesButton = app.buttons["findRecipesButton"]
        XCTAssertTrue(findRecipesButton.waitForExistence(timeout: 5), "Find Recipes button should be visible after cuisine selection")
        findRecipesButton.tap()

        // Step 5: Wait for the Recipes navigation bar
        let recipesNavBar = app.navigationBars["Recipes"]
        XCTAssertTrue(recipesNavBar.waitForExistence(timeout: 10), "Should navigate to the Recipes screen")
    }

    /// Verify that a network error shows the error banner with the correct message
    /// and that the retry button is present.
    ///
    /// The app is launched with "--uitesting-network-error" which causes the mock
    /// RecipeEngineService to throw `RecipeEngineError.networkUnavailable`.
    /// The error banner should display the network error message and a retry button.
    ///
    /// Validates: Requirements 9.3
    @MainActor
    func testNetworkErrorShowsBannerAndRetryButton() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting-network-error"]
        app.launch()

        navigateToRecipeResultsViewWithNetworkError(app: app)

        // Wait for the error banner to appear (mock has a 0.3 s delay before throwing)
        let errorBanner = app.otherElements["errorBanner"]
        XCTAssertTrue(
            errorBanner.waitForExistence(timeout: 10),
            "Error banner should appear after a network error"
        )

        // Verify the error message text contains the expected network error message
        let errorBannerText = app.staticTexts["errorBannerText"]
        XCTAssertTrue(
            errorBannerText.waitForExistence(timeout: 5),
            "Error banner text should be present"
        )
        XCTAssertTrue(
            errorBannerText.label.contains("No internet connection"),
            "Error banner should display the network unavailable message, got: \(errorBannerText.label)"
        )

        // Verify the retry button is present
        // (it may be disabled when network is unavailable, but it must exist)
        let retryButton = app.buttons["retryButton"]
        XCTAssertTrue(
            retryButton.waitForExistence(timeout: 5),
            "Retry button should be present when a network error occurs"
        )
    }
}
