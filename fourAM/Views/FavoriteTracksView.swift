//
//  FavoriteTracksView.swift
//  fourAM
//
//  Created by Jonas on 2025-01-22.
//

import SwiftUI
import SwiftData

struct FavoriteTracksView: View {
    @ObservedObject var libraryViewModel = LibraryViewModel.shared
    @Environment(\.modelContext) private var modelContext
    @State private var favoriteTracks: [Track] = []

    var body: some View {
        VStack(alignment: .leading) {
            // Table Header
            HStack(alignment: .center) {
                Text("Song")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)
                    .padding(.trailing, 4)
                Text("Artist")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 6)
                Text("Album")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 3)
                Text("Genre")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Plays")
                    .frame(width: 60, alignment: .trailing) // Fixed width for numeric column
                Text("Duration")
                    .frame(width: 80, alignment: .trailing) // Fixed width for numeric column
                    .padding(.trailing, 24)
            }
            .font(.headline)
            .frame(height: 24)
            .padding(.horizontal, 0)
            .padding(.top, 8)

            // Table Rows
            List(favoriteTracks, id: \.id) { track in
                HStack {
                    Text(track.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(track.artist)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(track.album)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(track.genre ?? "-")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(track.playCount)")
                        .frame(width: 60, alignment: .trailing) // Matches header width
                    Text(track.durationString)
                        .frame(width: 80, alignment: .trailing) // Matches header width
                }
                .padding(.vertical, 4)
            }
            .listStyle(PlainListStyle())
        }
        .navigationTitle("Favorite Tracks")
        .onAppear {
            loadFavorites()
        }
    }

    private func loadFavorites() {
        do {
            let fetchDescriptor = FetchDescriptor<Track>(
                predicate: #Predicate { $0.favorite == true }
            )
            favoriteTracks = try modelContext.fetch(fetchDescriptor)
        } catch {
            print("Failed to load favorite tracks: \(error)")
        }
    }
}
