// FavouritesServiceKey.swift
// ChefNova
//
// SwiftUI environment key for injecting FavouritesService down the view hierarchy.

import SwiftUI

// MARK: - Environment Key

private struct FavouritesServiceKey: EnvironmentKey {
    /// Default is a no-op stub. The real service is injected from AppRootView.
    static let defaultValue: any FavouritesServiceProtocol = NoOpFavouritesService()
}

extension EnvironmentValues {
    var favouritesService: any FavouritesServiceProtocol {
        get { self[FavouritesServiceKey.self] }
        set { self[FavouritesServiceKey.self] = newValue }
    }
}
