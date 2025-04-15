import SwiftUI
import SwiftData
import AppKit

struct RecentlyAddedView: View {
    @ObservedObject var libraryViewModel: LibraryViewModel
    let onAlbumSelected: (Album) -> Void
    @Environment(\.modelContext) private var modelContext
    @AppStorage("coverImageSize") private var coverImageSize: Double = 120.0
    @State private var albums: [Album] = []
    @State private var loadAlbumsTask: Task<Void, Never>?
    
    var body: some View {
        VStack {
            if libraryViewModel.isLoadingAlbums {
                ProgressView("Loading albums...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if albums.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No albums found")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: coverImageSize, maximum: coverImageSize + 20), spacing: 16)], 
                        spacing: 16
                    ) {
                        ForEach(albums, id: \.id) { album in
                            AlbumItemView(
                                album: album,
                                coverImageSize: coverImageSize,
                                onAlbumSelected: onAlbumSelected,
                                onDelete: {
                                    Task {
                                        await loadAlbums() // Refresh the albums
                                    }
                                },
                                modelContext: modelContext,
                                libraryViewModel: libraryViewModel
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            loadAlbumsTask = Task {
                await loadAlbums()
            }
        }
        .onDisappear {
            loadAlbumsTask?.cancel()
        }
        .onChange(of: libraryViewModel.tracks) { oldValue, newValue in
            loadAlbumsTask?.cancel()
            loadAlbumsTask = Task {
                await loadAlbums()
            }
        }
        .task {
            await loadAlbums()
        }
        .navigationTitle("Recently Added")
    }
    
    private func loadAlbums() async {
        let allAlbums = await libraryViewModel.allAlbums()
        
        await MainActor.run {
            // Filter out albums without addition dates and sort by date
            albums = allAlbums
                .filter { album in
                    // Check if any track in the album has an addition date
                    album.tracks.contains { $0.additionDate != nil }
                }
                .sorted { album1, album2 in
                    // Get the earliest addition date from each album's tracks
                    let date1 = album1.tracks.compactMap { $0.additionDate }.min() ?? Date.distantPast
                    let date2 = album2.tracks.compactMap { $0.additionDate }.min() ?? Date.distantPast
                    return date1 > date2
                }
                .prefix(100)
                .map { $0 }
            
            print("\nRecently Added Albums Debug:")
            print("  Total albums in library: \(allAlbums.count)")
            print("  Albums with dates: \(albums.count)")
            
            // Print all albums with their dates to debug sorting
            print("\nAll albums with dates (sorted):")
            albums.enumerated().forEach { index, album in
                if let earliestDate = album.tracks.compactMap({ $0.additionDate }).min() {
                    print("  \(index + 1). \(album.name) - Added: \(earliestDate)")
                }
            }
            
            if let newest = albums.first,
               let newestDate = newest.tracks.compactMap({ $0.additionDate }).min() {
                print("\nNewest album: \(newest.name) added on \(newestDate)")
            }
            if let oldest = albums.last,
               let oldestDate = oldest.tracks.compactMap({ $0.additionDate }).min() {
                print("Oldest album: \(oldest.name) added on \(oldestDate)")
            }
            
            // Verify sorting
            let isSorted = albums.enumerated().allSatisfy { index, album in
                if index == 0 { return true }
                let currentDate = album.tracks.compactMap { $0.additionDate }.min() ?? Date.distantPast
                let previousDate = albums[index - 1].tracks.compactMap { $0.additionDate }.min() ?? Date.distantPast
                return currentDate <= previousDate
            }
            print("\nSorting verification: \(isSorted ? "Correct" : "Incorrect")")
        }
    }
}

#Preview {
    RecentlyAddedView(
        libraryViewModel: LibraryViewModel.shared,
        onAlbumSelected: { _ in }
    )
} 