// FavouritesService.swift
// ChefNova
//
// Saves, removes, and queries favourite recipes using a SwiftData ModelContext.

import Foundation
import SwiftData

// MARK: - Protocol

protocol FavouritesServiceProtocol {
    /// Returns `true` if a recipe with the given ID is already saved.
    func isFavourite(recipeID: UUID) -> Bool

    /// Saves the given recipe. Silently no-ops if already saved.
    func save(rankedRecipe: RankedRecipe) throws

    /// Removes the recipe with the given ID. Silently no-ops if not found.
    func remove(recipeID: UUID) throws

    /// Returns all saved recipes sorted by `savedAt` descending.
    func fetchAll() -> [FavouriteRecipe]
}

// MARK: - Implementation

final class FavouritesService: FavouritesServiceProtocol {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func isFavourite(recipeID: UUID) -> Bool {
        let id = recipeID
        var descriptor = FetchDescriptor<FavouriteRecipe>(
            predicate: #Predicate { $0.recipeID == id }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor).first) != nil
    }

    func save(rankedRecipe: RankedRecipe) throws {
        guard !isFavourite(recipeID: rankedRecipe.id) else { return }
        let favourite = try FavouriteRecipe(rankedRecipe: rankedRecipe)
        context.insert(favourite)
        try context.save()
    }

    func remove(recipeID: UUID) throws {
        let id = recipeID
        let descriptor = FetchDescriptor<FavouriteRecipe>(
            predicate: #Predicate { $0.recipeID == id }
        )
        guard let existing = try? context.fetch(descriptor).first else { return }
        context.delete(existing)
        try context.save()
    }

    func fetchAll() -> [FavouriteRecipe] {
        let descriptor = FetchDescriptor<FavouriteRecipe>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
