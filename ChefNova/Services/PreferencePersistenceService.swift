// PreferencePersistenceService.swift
// ChefNova
//
// Saves and loads the user's Preference Profile using SwiftData, enabling
// cuisine, dietary preference, and skill level selections to persist across
// app restarts and device reboots.

import Foundation
import SwiftData

// MARK: - Protocol

/// Defines the interface for preference profile persistence.
protocol PreferencePersistenceServiceProtocol {
    /// Persists the given preference profile to the SwiftData store.
    ///
    /// Inserts the profile into the model context and commits the change.
    /// Throws if the underlying `ModelContext.save()` call fails.
    func savePreferences(_ profile: PreferenceProfile) throws

    /// Returns the most recently saved preference profile, or `nil` if none exists.
    ///
    /// "Most recent" is determined by the `savedAt` timestamp in descending order.
    func loadLatestPreferences() -> PreferenceProfile?
}

// MARK: - Implementation

/// Persists and retrieves `PreferenceProfile` records using a SwiftData
/// `ModelContext`. The service is designed to be injected via its protocol
/// so that callers can be tested with an in-memory container.
final class PreferencePersistenceService: PreferencePersistenceServiceProtocol {

    // MARK: Private state

    private let context: ModelContext

    // MARK: Init

    /// Creates the service with the given SwiftData model context.
    ///
    /// - Parameter context: The `ModelContext` used for all read and write
    ///   operations. Typically the app's main context; pass an in-memory
    ///   context in tests.
    init(context: ModelContext) {
        self.context = context
    }

    // MARK: PreferencePersistenceServiceProtocol

    /// Inserts `profile` into the model context and saves.
    ///
    /// Each call inserts a new record; the most recent record is always
    /// retrieved by `loadLatestPreferences` via the `savedAt` sort.
    ///
    /// - Throws: Any error propagated by `ModelContext.save()`.
    func savePreferences(_ profile: PreferenceProfile) throws {
        context.insert(profile)
        try context.save()
    }

    /// Fetches all `PreferenceProfile` records sorted by `savedAt` descending
    /// and returns the first (most recent) one, or `nil` if the store is empty.
    func loadLatestPreferences() -> PreferenceProfile? {
        var descriptor = FetchDescriptor<PreferenceProfile>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        return try? context.fetch(descriptor).first
    }
}
