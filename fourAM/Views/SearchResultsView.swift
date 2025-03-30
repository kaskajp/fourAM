import SwiftUI
import SwiftData

struct SearchResultsView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var libraryViewModel = LibraryViewModel.shared
    @Environment(\.modelContext) private var modelContext
    
    var onAlbumSelected: ((Album) -> Void)?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if appState.searchResults.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try searching for something else")
                    )
                } else {
                    // Display albums section
                    if !appState.searchResults.albums.isEmpty {
                        Text("Albums")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                            .padding(.top)
                        
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 160, maximum: 180), spacing: 16)],
                            spacing: 16
                        ) {
                            ForEach(appState.searchResults.albums, id: \.id) { album in
                                AlbumItemView(
                                    album: album, 
                                    coverImageSize: 160,
                                    onAlbumSelected: onAlbumSelected,
                                    onDelete: { },
                                    modelContext: modelContext,
                                    libraryViewModel: libraryViewModel
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Display tracks section
                    if !appState.searchResults.tracks.isEmpty {
                        Text("Tracks")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                            .padding(.top, 20)
                        
                        VStack(spacing: 2) {
                            ForEach(appState.searchResults.tracks, id: \.id) { track in
                                TrackRowView(
                                    track: track,
                                    isPlaying: Binding(
                                        get: { PlaybackManager.shared.currentTrack?.id == track.id },
                                        set: { _ in }
                                    ),
                                    trackIndex: 0,
                                    showAlbumInfo: true,
                                    modelContext: modelContext
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    PlaybackManager.shared.play(
                                        track: track,
                                        tracks: appState.searchResults.tracks
                                    )
                                }
                                
                                Divider()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Search Results: \"\(appState.globalSearchQuery)\"")
    }
}
