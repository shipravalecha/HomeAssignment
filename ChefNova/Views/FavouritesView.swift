// FavouritesView.swift
// ChefNova
//
// Displays the user's saved favourite recipes and allows navigation to detail.

import SwiftUI

struct FavouritesView: View {

    @Environment(\.favouritesService) private var favouritesService
    @State private var favourites: [FavouriteRecipe] = []

    var body: some View {
        Group {
            if favourites.isEmpty {
                ContentUnavailableView(
                    "No Favourites Yet",
                    systemImage: "heart.slash",
                    description: Text("Save a recipe by tapping the heart icon on any recipe.")
                )
            } else {
                List {
                    ForEach(favourites, id: \.recipeID) { favourite in
                        if let ranked = favourite.rankedRecipe {
                            NavigationLink(destination: RecipeDetailView(viewModel: RecipeDetailViewModel(rankedRecipe: ranked))) {
                                favouriteRow(favourite)
                            }
                        }
                    }
                    .onDelete(perform: deleteFavourites)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Favourites")
        .onAppear { reload() }
    }

    // MARK: - Row

    private func favouriteRow(_ favourite: FavouriteRecipe) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(favourite.title)
                .font(.headline)
            HStack(spacing: 12) {
                Label(favourite.cuisine, systemImage: "fork.knife")
                Label("\(favourite.totalTimeMinutes) min", systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func reload() {
        favourites = favouritesService.fetchAll()
    }

    private func deleteFavourites(at offsets: IndexSet) {
        for index in offsets {
            let favourite = favourites[index]
            try? favouritesService.remove(recipeID: favourite.recipeID)
        }
        reload()
    }
}
