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
    @Query private var items: [Item]

    @StateObject private var libraryViewModel = LibraryViewModel()
    
    // Group audio files by artist
    private var artistsDictionary: [String: [Track]] {
        Dictionary(grouping: libraryViewModel.tracks, by: \.artist)
    }

    // Create a sorted list of artist names
    private var artistNames: [String] {
        artistsDictionary.keys.sorted()
    }

    var body: some View {
        NavigationSplitView {
            List {
                // 2. Music library section
                Section("Library") {
                    // 1) Artists
                    NavigationLink("Artists") {
                        ArtistsView(libraryViewModel: libraryViewModel)
                    }
                    // 2) Albums
                    NavigationLink("Albums") {
                        AlbumsView(libraryViewModel: libraryViewModel)
                    }
                    // 3) Tracks
                    NavigationLink("Tracks") {
                        TracksView(libraryViewModel: libraryViewModel)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar {
                // 5. New "Add Folder" button for scanning music
                ToolbarItem {
                    Button(action: pickFolder) {
                        Label("Add Folder", systemImage: "folder.badge.plus")
                    }
                }
                ToolbarItem {
                    // Button to fetch & display the saved tracks
                    Button("Fetch Saved Tracks", systemImage: "folder.badge.minus") {
                        libraryViewModel.fetchTracks(context: modelContext)
                    }
                }
            }
        } detail: {
            Text("Select an item (or track)")
                .padding()
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
            // Use the libraryViewModel to scan & insert tracks into SwiftData
            libraryViewModel.loadLibrary(folderPath: selectedFolder.path, context: modelContext)
            // Optionally fetch again afterwards
            libraryViewModel.fetchTracks(context: modelContext)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
