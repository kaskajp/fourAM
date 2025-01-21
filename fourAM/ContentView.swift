//
//  ContentView.swift
//  fourAM
//
//  Created by Jonas on 2025-01-05.
//

import SwiftUI
import SwiftData
import AppKit // Needed for NSOpenPanel on macOS

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @StateObject private var libraryViewModel = LibraryViewModel.shared
    @ObservedObject var playbackManager = PlaybackManager.shared
    
    @State private var selectedView: String? = nil
    @State private var selectedAlbum: Album? = nil
    @State private var refreshAction: (() -> Void)? = nil
    
    // Group audio files by artist
    private var artistsDictionary: [String: [Track]] {
        Dictionary(grouping: libraryViewModel.tracks, by: \.artist)
    }

    // Create a sorted list of artist names
    private var artistNames: [String] {
        artistsDictionary.keys.sorted()
    }

    var body: some View {
        VStack(spacing: 0) { // Ensures no gap between the navigation view and the playback controls
            NavigationSplitView {
                List(selection: $selectedView) {
                    // Processing Section
                    if libraryViewModel.isScanning {
                        Section("Processing") {
                            VStack(alignment: .leading) {
                                Text(libraryViewModel.currentPhase)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                ProgressView(value: libraryViewModel.progress, total: 1.0)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Section("Library") {
                        NavigationLink(value: "ArtistsView") {
                            HStack(spacing: 4) {
                                Image(systemName: "music.microphone")
                                    .foregroundColor(.indigo)
                                Text("Artists")
                            }
                        }
                        NavigationLink(value: "AlbumsView") {
                            HStack(spacing: 4) {
                                Image(systemName: "square.stack")
                                    .foregroundColor(.indigo)
                                Text("Albums")
                            }
                        }
                        NavigationLink(value: "TracksView") {
                            HStack(spacing: 4) {
                                Image(systemName: "music.note.list")
                                    .foregroundColor(.indigo)
                                Text("Tracks")
                            }
                        }
                    }
                }
                .toolbar {
                    ToolbarItem {
                        Button(action: pickFolder) {
                            Label("Add Folder", systemImage: "folder.badge.plus")
                        }
                    }
                }
                .frame(minWidth: 180) 
            } detail: {
                if selectedView == "AlbumsView" {
                    AlbumsView(
                        libraryViewModel: libraryViewModel,
                        onAlbumSelected: { album in
                            selectedAlbum = album
                            selectedView = "AlbumDetailView"
                        },
                        onSetRefreshAction: { action in
                            refreshAction = action
                        }
                    )
                } else if selectedView == "AlbumDetailView", let album = selectedAlbum {
                    AlbumDetailView(album: album) {
                        selectedView = "AlbumsView" // Navigate back to AlbumsView
                    }
                } else if selectedView == "ArtistsView" {
                    ArtistsView(libraryViewModel: libraryViewModel)
                } else if selectedView == "TracksView" {
                    TracksView(libraryViewModel: libraryViewModel)
                } else {
                    AlbumsView(libraryViewModel: libraryViewModel, onAlbumSelected: { album in
                        selectedAlbum = album
                        selectedView = "AlbumDetailView"
                    })
                }
            }

            // Playback controls spanning across the bottom of the window
            PlaybackControlsView()
                .frame(maxWidth: .infinity) // Ensures it spans the full width of the window
        }
        .onAppear {
            libraryViewModel.tracks = LibraryHelper.fetchTracks(from: modelContext)
            print("Library loaded on appear with \(libraryViewModel.tracks.count) tracks")
        }
    }

    // MARK: - Folder Picker for Music

    /// Opens an NSOpenPanel to pick a folder, then scans audio files.
    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let selectedFolder = panel.url {
            do {
                // Save a bookmark for the folder
                try BookmarkManager.storeBookmark(for: selectedFolder)
                print("Bookmark stored for folder: \(selectedFolder.path)")

                // Start accessing the folder's security scope
                guard selectedFolder.startAccessingSecurityScopedResource() else {
                    print("Failed to start accessing security scope for folder")
                    return
                }
                defer { selectedFolder.stopAccessingSecurityScopedResource() }

                // Perform scanning on a background queue
                DispatchQueue.global(qos: .userInitiated).async {
                    let fileManager = FileManager.default
                    let enumerator = fileManager.enumerator(
                        at: selectedFolder,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    )

                    // Collect all files to determine progress
                    let allFiles = (enumerator?.compactMap { $0 as? URL } ?? []).filter { url in
                        ["mp3", "m4a", "flac"].contains(url.pathExtension.lowercased())
                    }
                    let totalFiles = allFiles.count

                    if totalFiles == 0 {
                        DispatchQueue.main.async {
                            libraryViewModel.progress = 1.0
                            libraryViewModel.isScanning = false
                            print("No audio files found.")
                        }
                        return
                    }

                    DispatchQueue.main.async {
                        libraryViewModel.isScanning = true
                    }
                    var processedFiles = 0

                    // Process each file and update progress
                    for fileURL in allFiles {
                        do {
                            try BookmarkManager.storeBookmark(for: fileURL)
                            processedFiles += 1

                            // Update progress on the main thread
                            DispatchQueue.main.async {
                                libraryViewModel.progress = Double(processedFiles) / Double(totalFiles)
                            }
                        } catch {
                            print("Error storing bookmark for \(fileURL.path): \(error)")
                        }
                    }

                    // Scanning complete, update UI
                    DispatchQueue.main.async {
                        libraryViewModel.isScanning = false
                        libraryViewModel.progress = 1.0 // Ensure progress bar shows 100%
                        print("Scanning complete. Found \(totalFiles) audio files.")
                        libraryViewModel.loadLibrary(folderPath: selectedFolder.path, context: modelContext)
                        
                        if selectedView == "AlbumsView" {
                            refreshAction?() // Trigger refresh if AlbumsView is active
                        }
                    }
                }
            } catch {
                print("Error processing folder: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
}
