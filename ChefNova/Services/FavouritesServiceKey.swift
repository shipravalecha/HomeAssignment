// FavouritesServiceKey.swift
// ChefNova
//
// SwiftUI environment key for injecting FavouritesService down the view hierarchy.

import SwiftUI
import SwiftData

// MARK: - Environment Key

private struct FavouritesServiceKey: EnvironmentKey {
    /// Fallback used in previews and tests — operates on an in-memory container.
    @MainActor static let defaultValue: FavouritesServiceProtocol = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(for: FavouriteRecipe.self, configurations: config)
        return FavouritesService(context: ModelContext(container))
    }()
}

extension EnvironmentValues {
    var favouritesService: any FavouritesServiceProtocol {
        get { self[FavouritesServiceKey.self] }
        set { self[FavouritesServiceKey.self] = newValue }
    }
}
