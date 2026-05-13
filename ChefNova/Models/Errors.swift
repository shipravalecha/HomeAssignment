// Errors.swift
// ChefNova
//
// Error types for the Recipe Engine and ingredient validation.

import Foundation

/// Errors thrown by `RecipeEngineService` during recipe generation.
enum RecipeEngineError: Error, LocalizedError {
    /// The request exceeded the 10-second timeout.
    case timeout
    /// No network path was available when the request was made.
    case networkUnavailable
    /// The server returned an HTTP 5xx response.
    case serverError(statusCode: Int, logMessage: String)
    /// The engine returned a valid response but with an empty recipes array.
    case noResultsFound
    /// The response could not be decoded into the expected schema.
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "This is taking longer than expected. Please try again."
        case .networkUnavailable:
            return "No internet connection. Please check your network and try again."
        case .serverError(let statusCode, _):
            if statusCode == 401 {
                return "Invalid or missing API key. Please check your OpenAI API key in the Xcode scheme environment variables."
            } else if statusCode == 429 {
                return "OpenAI rate limit reached or no billing credits. Please check your OpenAI account."
            }
            return "Something went wrong on our end. Please try again shortly."
        case .noResultsFound:
            return "No recipes found for your inputs. Try adding more ingredients or changing your filters."
        case .invalidResponse:
            return "We received an unexpected response. Please try again."
        }
    }
}

/// Errors thrown during ingredient list validation.
enum IngredientValidationError: Error {
    /// The submitted name could not be mapped to any known canonical ingredient.
    case unrecognized(rawName: String)
    /// The ingredient list is empty when recipe generation was attempted.
    case emptyList
    /// All submitted ingredient entries consist entirely of whitespace.
    case allWhitespace
}
