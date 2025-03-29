import SwiftUI
import SwiftData
import AppKit // Needed for NSOpenPanel on macOS

// Define the possible selection values
enum SelectionValue: Hashable {
    case albums
    case albumDetail(Album)
    case favoriteTracks
    case playlist(Playlist)
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @StateObject private var libraryViewModel = LibraryViewModel.shared
    @ObservedObject var playbackManager = PlaybackManager.shared
    
    @State private var selectedView: Set<SelectionValue> = []
    @State private var selectedAlbum: Album? = nil
    @State private var refreshAction: (() -> Void)? = nil
    @State private var scrollPosition: String? = nil
    @State private var showNewPlaylistSheet = false
    @State private var showRenamePlaylistSheet = false
    @State private var playlistToRename: Playlist? = nil
    @Query private var playlists: [Playlist]
    
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
                        .id("processingSection")
                        .onAppear {
                            scrollPosition = "processingSection"
                        }
                    }
                    
                    Section("Library") {
                        NavigationLink(value: SelectionValue.albums) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.stack")
                                    .foregroundColor(.indigo)
                                Text("Albums")
                            }
                        }
                    }
                    
                    Section("Playlists") {
                        NavigationLink(value: SelectionValue.favoriteTracks) {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.indigo)
                                Text("Favorite Tracks")
                            }
                        }
                        
                        ForEach(playlists) { playlist in
                            NavigationLink(value: SelectionValue.playlist(playlist)) {
                                HStack(spacing: 4) {
                                    Image(systemName: "music.note.list")
                                        .foregroundColor(.indigo)
                                    Text(playlist.name)
                                }
                            }
                            .contextMenu {
                                Button {
                                    playlistToRename = playlist
                                    showRenamePlaylistSheet = true
                                } label: {
                                    Label("Rename Playlist", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    // If this playlist is currently selected, switch to AlbumsView
                                    if selectedView.contains(.playlist(playlist)) {
                                        selectedView = [.albums]
                                    }
                                    
                                    // Remove all tracks from the playlist first
                                    playlist.tracks.removeAll()
                                    // Delete the playlist
                                    modelContext.delete(playlist)
                                    try? modelContext.save()
                                } label: {
                                    Label("Delete Playlist", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .scrollPosition(id: $scrollPosition, anchor: .top)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button(action: pickFolder) {
                            Label("Add Folder", systemImage: "folder.badge.plus")
                        }
                    }
                    
                    ToolbarItem(placement: .automatic) {
                        Button {
                            showNewPlaylistSheet = true
                        } label: {
                            Label("New Playlist", systemImage: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showNewPlaylistSheet) {
                    NewPlaylistSheet(track: nil)
                }
                .sheet(isPresented: $showRenamePlaylistSheet) {
                    if let playlist = playlistToRename {
                        RenamePlaylistSheet(playlist: playlist)
                    }
                }
                .onChange(of: showRenamePlaylistSheet) { _, isPresented in
                    if !isPresented {
                        playlistToRename = nil
                    }
                }
                .frame(minWidth: 180)
            } detail: {
                Group {
                    if let selection = selectedView.first {
                        switch selection {
                        case .albums:
                            AlbumsView(
                                libraryViewModel: libraryViewModel,
                                onAlbumSelected: { album in
                                    selectedAlbum = album
                                    selectedView = [.albumDetail(album)]
                                },
                                onSetRefreshAction: { action in
                                    refreshAction = action
                                }
                            )
                        case .albumDetail(let album):
                            AlbumDetailView(
                                album: album,
                                onBack: {
                                    selectedView = [.albums]
                                },
                                modelContext: .init(\.modelContext),
                                libraryViewModel: libraryViewModel,
                                dismiss: .init(\.dismiss)
                            )
                        case .favoriteTracks:
                            FavoriteTracksView(libraryViewModel: libraryViewModel)
                        case .playlist(let playlist):
                            PlaylistDetailView(playlist: playlist)
                        }
                    } else {
                        AlbumsView(libraryViewModel: libraryViewModel, onAlbumSelected: { album in
                            selectedAlbum = album
                            selectedView = [.albumDetail(album)]
                        })
                    }
                }
            }

            // Playback controls spanning across the bottom of the window
            PlaybackControlsView()
                .frame(maxWidth: .infinity) // Ensures it spans the full width of the window
        }
        .onAppear {
            PlaybackManager.shared.setModelContext(modelContext)
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
                        
                        if selectedView.contains(.albums) {
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
