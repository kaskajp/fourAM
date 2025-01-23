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
    @State private var selectedTrack: Track?

    var body: some View {
        VStack(alignment: .leading) {
            // Table Header
            HStack(alignment: .center) {
                Text("Song")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                    .padding(.trailing, 16)
                Text("Artist")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                    .padding(.trailing, 16)
                Text("Album")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)
                    .padding(.trailing, 16)
                Text("Genre")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)
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
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(trackBackground(for: track))
                .cornerRadius(4)
                .contentShape(Rectangle()) // Ensures the full row is tappable
                .listRowSeparator(.hidden) // Remove separator between rows
                .listRowInsets(EdgeInsets()) // Remove all default List row insets
                .onTapGesture {
                    // Single-click to select the track
                    selectedTrack = track
                }
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        // Double-click to play the track
                        PlaybackManager.shared.play(track: track)
                    }
                )
                .contextMenu {
                    Button("Reset Play Count") {
                        libraryViewModel.resetPlayCountForTrack(for: track, context: modelContext)
                    }
                }
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
    
    private func trackBackground(for track: Track) -> Color {
        if selectedTrack == track {
            return Color.indigo.opacity(0.4)
        } else if let index = favoriteTracks.firstIndex(where: { $0.id == track.id }),
                  index.isMultiple(of: 2) {
            return Color.clear
        } else {
            return Color.black.opacity(0.1)
        }
    }
}
