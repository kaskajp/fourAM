//
//  AlbumsView.swift
//  fourAM
//
//  Created by Jonas on 2025-01-06.
//

import SwiftUI
import SwiftData
import AppKit

struct AlbumsView: View {
    @ObservedObject var libraryViewModel = LibraryViewModel.shared
    @StateObject private var keyMonitorManager = KeyMonitorManager()
    var onAlbumSelected: ((Album) -> Void)? = nil
    var onSetRefreshAction: ((@escaping () -> Void) -> Void)?
    @Environment(\.modelContext) private var modelContext
    @AppStorage("coverImageSize") private var coverImageSize: Double = 120.0
    @State private var searchQuery: String = "" // Search query for filtering albums
    @State private var debouncedSearchQuery: String = ""
    @StateObject private var timerManager = TimerManager()
    @State private var filteredAlbums: [Album] = [] // Filtered albums
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack {
            HStack {
                Spacer() // Push the search field to the right
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray) // Set the color of the icon
                    TextField("Search Albums or Artists", text: $searchQuery)
                        .textFieldStyle(PlainTextFieldStyle()) // Use a plain style for better integration
                        .frame(maxWidth: 200)
                        .focused($isSearchFieldFocused)
                        .onChange(of: searchQuery) { newValue in
                            filterAlbums()
                        }
                }
                .padding(8) // Add padding around the field
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2)) // Light gray background
                )
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: coverImageSize), spacing: 16)], spacing: 16) {
                    ForEach(filteredAlbums, id: \.id) { album in
                        AlbumItemView(
                            album: album,
                            coverImageSize: coverImageSize,
                            onAlbumSelected: onAlbumSelected,
                            onDelete: {
                                filterAlbums() // Refresh the filtered albums
                            },
                            modelContext: modelContext,
                            libraryViewModel: libraryViewModel
                        )
                    }
                }
                .padding()
            }
        }
        .onAppear {
            keyMonitorManager.startMonitoring { isSearchFieldFocused }
            filterAlbums() // Cache albums once
            onSetRefreshAction?(filterAlbums) // Register filterAlbums as the refresh action
        }
        .onDisappear {
            keyMonitorManager.stopMonitoring()
        }
        .onChange(of: debouncedSearchQuery) { newQuery in
            filterAlbums()
        }
        .onChange(of: libraryViewModel.tracks) { _ in
            filterAlbums() // Reapply filters when tracks change
        }
        .navigationTitle("Albums")
    }
    
    private func filterAlbums() {
        let albums = libraryViewModel.allAlbums() // Call once
        if searchQuery.isEmpty {
            filteredAlbums = albums
        } else {
            let lowercaseQuery = searchQuery.lowercased()
            filteredAlbums = albums.filter { album in
                album.name.lowercased().contains(lowercaseQuery) ||
                album.albumArtist.lowercased().contains(lowercaseQuery)
            }
        }
    }
    
    private func onSearchQueryChange() {
        timerManager.debounce(interval: 0.3) {
            DispatchQueue.main.async {
                debouncedSearchQuery = searchQuery
            }
        }
    }
}

struct AlbumItemView: View {
    let album: Album
    let coverImageSize: Double
    var onAlbumSelected: ((Album) -> Void)?
    let onDelete: (() -> Void)?
    let modelContext: ModelContext
    let libraryViewModel: LibraryViewModel

    var body: some View {
        Button(action: {
            onAlbumSelected?(album)
        }) {
            VStack(alignment: .leading) {
                // Render cover art or placeholder
                if let data = album.thumbnail, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: coverImageSize, height: coverImageSize)
                        .cornerRadius(4)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: coverImageSize, height: coverImageSize)
                        .cornerRadius(4)
                }
                
                // Album name
                Text(album.name)
                    .font(.headline)
                    .lineLimit(1)
                    .padding(.bottom, 0)

                // Album artist
                Text(album.albumArtist)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
            .frame(width: coverImageSize)
            .contextMenu {
                Button(role: .destructive) {
                    libraryViewModel.deleteAlbum(album, context: modelContext)
                    onDelete?()
                } label: {
                    Text("Remove from Library")
                }

                Button("Show in Finder") {
                    showAlbumInFinder(album)
                }
                Button("Rescan") {
                    libraryViewModel.rescanAlbum(album, context: modelContext)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // Helper to show album in Finder
    private func showAlbumInFinder(_ album: Album) {
        guard let firstTrack = album.tracks.first else { return }
        let fullTrackPath = firstTrack.path
        guard let topLevelFolderPath = LibraryHelper.findTopLevelFolder(for: fullTrackPath),
              let resolvedFolder = BookmarkManager.resolveBookmark(for: topLevelFolderPath),
              resolvedFolder.startAccessingSecurityScopedResource() else {
            print("Cannot resolve security scope.")
            return
        }
        defer { resolvedFolder.stopAccessingSecurityScopedResource() }

        let relativeSubPath = fullTrackPath.dropFirst(topLevelFolderPath.count)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let subfolderURL = resolvedFolder.appendingPathComponent(relativeSubPath, isDirectory: false)
        NSWorkspace.shared.open(subfolderURL.deletingLastPathComponent())
    }
}
