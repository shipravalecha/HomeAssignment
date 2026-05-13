# Requirements Document

## Introduction

ChefNova is an iOS mobile application that helps users decide what to cook based on the ingredients they already have. The app uses AI to generate contextually relevant recipe suggestions filtered by cuisine, dietary preference, and cooking skill level. It also recommends minimal additional ingredients when no complete recipe match is found, reducing food waste and helping users discover new dishes.

The MVP targets working professionals, students, and home cooks who want quick, personalized cooking guidance without needing to plan ahead.

---

## Glossary

- **App**: The ChefNova iOS mobile application.
- **User**: A person using the App on an iOS device.
- **Ingredient**: A food item entered by the User as available for cooking.
- **Ingredient List**: The collection of Ingredients provided by the User for a given session.
- **Normalizer**: The component responsible for mapping ingredient name variants to a canonical form.
- **Recipe**: A structured cooking instruction set including a title, ingredient list with quantities, serving size, steps, skill level, cuisine type, and dietary classification.
- **Recipe Engine**: The AI-powered backend component that generates and ranks Recipes based on User inputs.
- **Match Score**: A numeric value representing how closely a Recipe's required ingredients align with the User's Ingredient List.
- **Partial Match**: A Recipe that requires one or more Ingredients not present in the User's Ingredient List.
- **Gap Ingredients**: The minimal set of additional Ingredients required to complete a Partial Match Recipe.
- **Cuisine**: A culinary tradition used to filter Recipe generation (e.g., North Indian).
- **Dietary Preference**: A dietary classification selected by the User (Vegetarian or Non-Vegetarian).
- **Skill Level**: A cooking proficiency tier selected by the User: Beginner, Intermediate/Pro, or Chef Level.
- **Preference Profile**: A persisted record of the User's past Cuisine, Dietary Preference, and Skill Level selections.
- **Session**: A single interaction cycle from ingredient input through recipe results.
- **Pantry Staples**: A predefined set of commonly available basic spices and condiments that the App assumes are always present in the User's kitchen, based on the selected Cuisine. For example, the North Indian Pantry Staples list includes: salt, black pepper, red chilli powder, turmeric, cumin seeds, coriander powder, garam masala, and oil.

---

## Requirements

### Requirement 1: Ingredient Input

**User Story:** As a User, I want to manually enter the ingredients I have available, so that the App can generate relevant recipe suggestions for me.

#### Acceptance Criteria

1. THE App SHALL provide a text input field that accepts free-form ingredient names.
2. WHEN the User submits an ingredient name, THE App SHALL add it to the Ingredient List for the current Session.
3. WHEN the User submits an ingredient name, THE Normalizer SHALL map the submitted name to a canonical ingredient form using synonym mapping (e.g., "Onions", "Red Onion", and "Onion" all map to "Onion").
4. WHEN the User submits a name that cannot be mapped to any known ingredient, THE App SHALL display an inline validation message indicating the ingredient was not recognized and prompt the User to revise the entry.
5. THE App SHALL allow the User to remove any Ingredient from the Ingredient List before generating recipes.
6. THE App SHALL display the current Ingredient List to the User at all times during input.
7. WHEN the User attempts to generate recipes with an empty Ingredient List, THE App SHALL display an error message requiring at least one valid Ingredient before proceeding.

---

### Requirement 2: Cuisine and Dietary Preference Selection

**User Story:** As a User, I want to select my preferred cuisine and optionally filter by dietary preference, so that the recipes generated match my eating habits and tastes.

#### Acceptance Criteria

1. THE App SHALL present a Cuisine selector with at least "North Indian" as an available option.
2. THE App SHALL present a Dietary Preference selector with "Vegetarian", "Non-Vegetarian", and a default unselected state as options.
3. WHEN the User attempts to generate recipes without selecting a Cuisine, THE App SHALL display an error message requiring a Cuisine selection before proceeding.
4. WHEN the User does not select a Dietary Preference, THE Recipe Engine SHALL return Recipes of both Vegetarian and Non-Vegetarian classifications.
5. WHEN a Preference Profile exists for the User, THE App SHALL pre-populate the Cuisine and Dietary Preference selectors with the values from the most recent Preference Profile.

---

### Requirement 3: Skill Level Selection

**User Story:** As a User, I want to select my cooking skill level, so that the recipes I receive match my ability and available time.

#### Acceptance Criteria

1. THE App SHALL present a Skill Level selector with three options: Beginner, Intermediate/Pro, and Chef Level.
2. WHEN the User selects Beginner, THE Recipe Engine SHALL generate Recipes that use a minimal ingredient count, contain simple step-by-step instructions, and have a total preparation and cooking time of 30 minutes or less.
3. WHEN the User selects Intermediate/Pro, THE Recipe Engine SHALL generate Recipes that may include optional enhancement ingredients and techniques beyond basic cooking methods.
4. WHEN the User selects Chef Level, THE Recipe Engine SHALL generate Recipes that use from-scratch preparation methods and authentic culinary techniques (e.g., fresh dough, homemade sauces).
5. WHEN the User does not select a Skill Level, THE Recipe Engine SHALL default to generating Recipes at the Beginner level.
6. WHEN a Preference Profile exists for the User, THE App SHALL pre-populate the Skill Level selector with the value from the most recent Preference Profile.

---

### Requirement 4: Recipe Generation

**User Story:** As a User, I want the App to generate recipe suggestions based on my inputs, so that I can quickly decide what to cook with what I have.

#### Acceptance Criteria

1. WHEN the User submits a valid Ingredient List and Cuisine, THE Recipe Engine SHALL return a ranked list of Recipes ordered by Match Score in descending order, applying any Dietary Preference and Skill Level filters the User has selected.
2. WHEN the Ingredient List contains at least one valid Ingredient and matching Recipes exist, THE Recipe Engine SHALL return at least 3 Recipe suggestions.
3. WHEN fewer than 3 complete Recipe matches exist for the given inputs, THE Recipe Engine SHALL include Partial Match Recipes in the results to reach at least 3 suggestions, provided Partial Match Recipes are available.
4. THE App SHALL display each Recipe with its title, Match Score, total preparation and cooking time, serving size, and Skill Level.
5. WHEN the Recipe Engine returns results, THE App SHALL display the results within 5 seconds of the User initiating generation.
6. WHEN the Recipe Engine returns no results for the given inputs, THE App SHALL display a message informing the User that no recipes were found and suggest modifying the Ingredient List or filters.

---

### Requirement 5: Smart Ingredient Gap Filling

**User Story:** As a User, I want to know what minimal additional ingredients I need to complete a recipe, so that I can decide whether to buy them or choose a different recipe.

#### Acceptance Criteria

1. WHEN a Partial Match Recipe is included in the results, THE App SHALL display the Gap Ingredients for that Recipe alongside the Recipe entry.
2. THE App SHALL present Gap Ingredients in order of commonality, with the most commonly available ingredients listed first.
3. WHEN Gap Ingredients are displayed, THE App SHALL provide a redirect link for each Gap Ingredient that opens a web search query for purchasing that ingredient.
4. THE App SHALL display no more than 5 Gap Ingredients per Partial Match Recipe in the results list.

---

### Requirement 6: Recipe Detail View

**User Story:** As a User, I want to view the full details of a recipe, so that I can follow the cooking instructions step by step.

#### Acceptance Criteria

1. WHEN the User selects a Recipe from the results list, THE App SHALL navigate to a Recipe Detail View.
2. THE Recipe Detail View SHALL display the Recipe title, cuisine type, dietary classification, Skill Level, total time, serving size, full ingredient list with quantities, and numbered cooking steps.
3. WHEN the Recipe Detail View is displayed, THE App SHALL allow the User to adjust the serving size, and THE App SHALL recalculate all ingredient quantities proportionally to the adjusted serving size.
4. THE Recipe Detail View SHALL display the Gap Ingredients section for Partial Match Recipes, clearly distinguishing Gap Ingredients from available Ingredients.

---

### Requirement 7: Ingredient Normalization

**User Story:** As a User, I want the App to understand common ingredient name variations, so that I do not need to type exact names to get accurate results.

#### Acceptance Criteria

1. THE Normalizer SHALL maintain a synonym mapping that maps common ingredient name variants and misspellings to a canonical ingredient name.
2. WHEN the Normalizer receives an ingredient name, THE Normalizer SHALL return the canonical form of that ingredient.
3. WHEN the Normalizer receives an ingredient name that has no matching canonical form, THE Normalizer SHALL return a not-recognized signal to the App.
4. FOR ALL canonical ingredient names, normalizing the canonical name SHALL return the same canonical name (idempotence property).
5. FOR ALL ingredient name variants in the synonym mapping, normalizing then re-normalizing the result SHALL return the same canonical name (round-trip stability property).

---

### Requirement 8: Preference Persistence

**User Story:** As a User, I want the App to remember my past preferences, so that I do not have to re-enter my cuisine, dietary, and skill settings every time I use the App.

#### Acceptance Criteria

1. WHEN the User successfully generates recipes, THE App SHALL save the Cuisine, Dietary Preference, and Skill Level used in that Session to the User's Preference Profile.
2. WHEN the App is launched and a Preference Profile exists, THE App SHALL load the most recent Preference Profile and pre-populate the Cuisine, Dietary Preference, and Skill Level selectors.
3. THE App SHALL persist the Preference Profile across App restarts and device reboots.
4. WHEN the User changes a selector value and generates recipes, THE App SHALL update the Preference Profile with the new values.

---

### Requirement 9: Error Handling and Input Validation

**User Story:** As a User, I want the App to handle invalid inputs and failures gracefully, so that I always understand what went wrong and how to recover.

#### Acceptance Criteria

1. WHEN the User submits an Ingredient List containing only unrecognized ingredient names, THE App SHALL display an error message listing the unrecognized entries and prompt the User to correct them before proceeding.
2. WHEN the Recipe Engine fails to respond within 10 seconds, THE App SHALL display a timeout error message and provide a retry action.
3. WHEN the App loses network connectivity during recipe generation, THE App SHALL display a connectivity error message and provide a retry action once connectivity is restored.
4. IF the Recipe Engine returns a server error, THEN THE App SHALL display a user-friendly error message and log the error details for diagnostic purposes without exposing technical details to the User.
5. WHEN the User submits an Ingredient List where all entries are empty strings or whitespace, THE App SHALL treat the Ingredient List as empty and display the empty-list validation error defined in Requirement 1.7.

---

### Requirement 10: Pantry Staples

**User Story:** As a User, I want the App to assume I have basic everyday spices and condiments for my selected cuisine, so that I do not have to manually enter them every time I cook.

#### Acceptance Criteria

1. THE App SHALL maintain a Pantry Staples list per Cuisine (e.g., for North Indian: salt, black pepper, red chilli powder, turmeric, cumin seeds, coriander powder, garam masala, oil).
2. WHEN the Recipe Engine evaluates ingredient matches, THE Recipe Engine SHALL treat all Pantry Staples for the selected Cuisine as implicitly available, regardless of whether the User has included them in the Ingredient List.
3. THE App SHALL NOT require the User to enter Pantry Staples in the Ingredient List.
4. THE App SHALL NOT list Pantry Staples as Gap Ingredients for Partial Match Recipes.
5. WHERE the App displays recipe results, THE App MAY display a Pantry Staples assumption notice to the User (e.g., "We assume you have basic spices like salt, turmeric, cumin...") so the User is aware of which ingredients are being treated as implicitly available.
