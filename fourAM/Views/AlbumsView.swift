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
    var onAlbumSelected: ((Album) -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @AppStorage("coverImageSize") private var coverImageSize: Double = 120.0

    // Cache the albums to avoid recalculating on every update
    @State private var cachedAlbums: [Album] = []

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: coverImageSize), spacing: 16)],
                spacing: 16
            ) {
                ForEach(cachedAlbums) { album in
                    AlbumItemView(
                        album: album,
                        coverImageSize: coverImageSize,
                        onAlbumSelected: onAlbumSelected,
                        modelContext: modelContext,
                        libraryViewModel: libraryViewModel
                    )
                }
            }
            .padding()
        }
        .onAppear {
            cachedAlbums = libraryViewModel.allAlbums() // Cache albums once
        }
        .onChange(of: libraryViewModel.tracks) { _ in
            cachedAlbums = libraryViewModel.allAlbums() // Refresh cache if tracks change
        }
        .navigationTitle("Albums")
    }
}

struct AlbumItemView: View {
    let album: Album
    let coverImageSize: Double
    var onAlbumSelected: ((Album) -> Void)?
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

                // Album artist
                Text(album.albumArtist)
                    .font(.caption)
                    .lineLimit(1)
                    .padding(.top, 4)

                // Album name
                Text(album.name)
                    .font(.headline)
                    .lineLimit(1)
            }
            .frame(width: coverImageSize)
            .contextMenu {
                Button(role: .destructive) {
                    libraryViewModel.deleteAlbum(album, context: modelContext)
                } label: {
                    Text("Remove from Library")
                }

                Button("Show in Finder") {
                    showAlbumInFinder(album)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // Helper to show album in Finder
    private func showAlbumInFinder(_ album: Album) {
        guard let firstTrack = album.tracks.first else { return }
        let fullTrackPath = firstTrack.path
        guard let topLevelFolderPath = findTopLevelFolder(for: fullTrackPath),
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

    private func findTopLevelFolder(for filePath: String) -> String? {
        let allTopLevelFolders = BookmarkManager.allStoredFolderPaths()
        return allTopLevelFolders.first { filePath.hasPrefix($0) }
    }
}
