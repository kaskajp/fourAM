import SwiftUI

struct ArtistsView: View {
    @ObservedObject var libraryViewModel: LibraryViewModel
    @State private var artistAlbums: [String: [Album]] = [:]
    @State private var isLoadingAlbums: Bool = false

    var body: some View {
        NavigationStack {
            List(libraryViewModel.allArtists, id: \.self) { artist in
                NavigationLink(
                    destination: ArtistDetailView(
                        artist: artist,
                        albums: artistAlbums[artist] ?? []
                    )
                ) {
                    Text(artist)
                }
                .task {
                    if artistAlbums[artist] == nil {
                        isLoadingAlbums = true
                        artistAlbums[artist] = await libraryViewModel.albums(for: artist)
                        isLoadingAlbums = false
                    }
                }
            }
            .navigationTitle("Artists")
            .overlay {
                if isLoadingAlbums {
                    ProgressView("Loading albums...")
                }
            }
        }
    }
}
