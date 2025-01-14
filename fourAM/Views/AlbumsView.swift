//
//  AlbumsView.swift
//  fourAM
//
//  Created by Jonas on 2025-01-06.
//

import SwiftUI
import AppKit

struct AlbumsView: View {
    @ObservedObject var libraryViewModel = LibraryViewModel.shared
    var onAlbumSelected: ((Album) -> Void)? = nil
    @Environment(\.modelContext) private var modelContext  // we need this to delete from SwiftData
    
    // Persistent setting for cover image size
    @AppStorage("coverImageSize") private var coverImageSize: Double = 120.0 // Default size

    var body: some View {
        ScrollView {
            // Adaptive grid based on cover image size
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: coverImageSize), spacing: 16)],
                spacing: 16
            ) {
                ForEach(libraryViewModel.allAlbums()) { album in
                    Button(action: {
                        onAlbumSelected?(album) // Call the closure when an album is selected
                    }) {
                        VStack(alignment: .leading) {
                            // Show cover art or a placeholder
                            if let data = album.artwork,
                               let nsImage = NSImage(data: data) {
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

                            // Artist name label
                            Text(album.albumArtist)
                                .font(.caption)
                                .lineLimit(1)
                                .padding(.top, 4)

                            // Album name label
                            Text(album.name)
                                .font(.headline)
                                .lineLimit(1)
                        }
                        .frame(width: coverImageSize)
                        .contextMenu {
                            Button(role: .destructive) {
                                // Call deleteAlbum in your LibraryViewModel
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
            }
            .padding()
        }
        .navigationTitle("Albums")
    }
    
    func findTopLevelFolder(for filePath: String) -> String? {
        // Suppose you have a list of stored top-level folder paths
        let allTopLevelFolders = BookmarkManager.allStoredFolderPaths()
        // Return the path that `filePath` starts with, if any
        return allTopLevelFolders.first { filePath.hasPrefix($0) }
    }
    
    // MARK: - Helper: Open the album folder in Finder
    private func showAlbumInFinder(_ album: Album) {
        guard let firstTrack = album.tracks.first else { return }
        let fullTrackPath = firstTrack.path  // e.g. "/Users/jonas/Music/FolderA/SubFolder/Album/track.mp3"

        let topLevelFolderPath = findTopLevelFolder(for: fullTrackPath)
        
        // Identify which top-level folder this belongs to
        guard let topLevelFolderPath = findTopLevelFolder(for: fullTrackPath),
              let resolvedFolder = BookmarkManager.resolveBookmark(for: topLevelFolderPath) else {
            print("No bookmark or can't resolve for \(String(describing: topLevelFolderPath))")
            return
        }

        // Start accessing the security scope
        guard resolvedFolder.startAccessingSecurityScopedResource() else {
            print("Could not start security scope for \(resolvedFolder.path)")
            return
        }
        defer { resolvedFolder.stopAccessingSecurityScopedResource() }

        // 4) Build the subfolder path (relative to topLevelFolderPath)
        let relativeSubPath = fullTrackPath.dropFirst(topLevelFolderPath.count)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        // Now "relativeSubPath" might be "SubFolder/Album/track.mp3"

        // 5) Create the subfolder's URL from the resolved top-level URL
        let subfolderURL = resolvedFolder.appendingPathComponent(relativeSubPath, isDirectory: false)
        // If you want just the album folder, remove the filename:
        // let albumFolderURL = subfolderURL.deletingLastPathComponent()

        // 6) Open that subfolder (or the album folder) in Finder
        NSWorkspace.shared.open(subfolderURL.deletingLastPathComponent())
        // or highlight the exact file:
        // NSWorkspace.shared.activateFileViewerSelecting([subfolderURL])
    }
}
