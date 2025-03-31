import SwiftUI
import SwiftData
import AppKit // Needed for NSOpenPanel on macOS

// Define the possible selection values
enum SelectionValue: Hashable {
    case albums
    case albumDetail(Album)
    case favoriteTracks
    case playlist(Playlist)
    case searchResults
    case recentlyAdded
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var appState = AppState.shared
    @State private var selectedView: Set<SelectionValue> = []
    @State private var selectedAlbum: Album? = nil
    @State private var refreshAction: (() -> Void)? = nil
    @State private var scrollPosition: String? = nil
    @State private var showNewPlaylistSheet = false
    @State private var showRenamePlaylistSheet = false
    @State private var playlistToRename: Playlist? = nil
    @Query private var playlists: [Playlist]
    @StateObject private var libraryViewModel = LibraryViewModel.shared
    @State private var searchDebounceTask: Task<Void, Never>?
    @ObservedObject var playbackManager = PlaybackManager.shared
    
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
                        
                        NavigationLink(value: SelectionValue.recentlyAdded) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .foregroundColor(.indigo)
                                Text("Recently Added")
                            }
                        }
                    }
                    
                    Section {
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
                    } header: {
                        Text("Playlists")
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button {
                                    showNewPlaylistSheet = true
                                } label: {
                                    Label("New Playlist", systemImage: "plus")
                                }
                            }
                    }
                }
                .scrollPosition(id: $scrollPosition, anchor: .top)
                .contextMenu {
                    Button {
                        showNewPlaylistSheet = true
                    } label: {
                        Label("New Playlist", systemImage: "plus")
                    }
                }
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
                            .toolbar {
                                ToolbarItemGroup(placement: .automatic) {
                                    // Custom search implementation
                                    HStack(spacing: 4) {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 12))
                                        
                                        TextField("Search", text: $appState.globalSearchQuery)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .font(.system(size: 13))
                                            .frame(width: 200)
                                            .onSubmit {
                                                Task {
                                                    await performGlobalSearch()
                                                }
                                            }
                                            .onChange(of: appState.globalSearchQuery) { _, newValue in
                                                searchDebounceTask?.cancel()
                                                searchDebounceTask = Task {
                                                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                                                    if !Task.isCancelled {
                                                        await performGlobalSearch()
                                                    }
                                                }
                                            }
                                        
                                        if !appState.globalSearchQuery.isEmpty {
                                            Button {
                                                appState.clearSearch()
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.gray)
                                                    .font(.system(size: 12))
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.2))
                                    )
                                    
                                    // Show search results button when there are results
                                    if !appState.searchResults.isEmpty {
                                        Button {
                                            selectedView = [.searchResults]
                                        } label: {
                                            Text("\(appState.searchResults.totalCount) results")
                                                .font(.system(size: 12))
                                        }
                                    }
                                }
                            }
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
                            .toolbar {
                                ToolbarItemGroup(placement: .automatic) {
                                    // Custom search implementation
                                    HStack(spacing: 4) {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 12))
                                        
                                        TextField("Search", text: $appState.globalSearchQuery)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .font(.system(size: 13))
                                            .frame(width: 200)
                                            .onSubmit {
                                                Task {
                                                    await performGlobalSearch()
                                                }
                                            }
                                            .onChange(of: appState.globalSearchQuery) { _, newValue in
                                                searchDebounceTask?.cancel()
                                                searchDebounceTask = Task {
                                                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                                                    if !Task.isCancelled {
                                                        await performGlobalSearch()
                                                    }
                                                }
                                            }
                                        
                                        if !appState.globalSearchQuery.isEmpty {
                                            Button {
                                                appState.clearSearch()
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.gray)
                                                    .font(.system(size: 12))
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.2))
                                    )
                                    
                                    // Show search results button when there are results
                                    if !appState.searchResults.isEmpty {
                                        Button {
                                            selectedView = [.searchResults]
                                        } label: {
                                            Text("\(appState.searchResults.totalCount) results")
                                                .font(.system(size: 12))
                                        }
                                    }
                                }
                            }
                        case .favoriteTracks:
                            FavoriteTracksView(libraryViewModel: libraryViewModel)
                            .toolbar {
                                ToolbarItemGroup(placement: .automatic) {
                                    // Custom search implementation
                                    HStack(spacing: 4) {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 12))
                                        
                                        TextField("Search", text: $appState.globalSearchQuery)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .font(.system(size: 13))
                                            .frame(width: 200)
                                            .onSubmit {
                                                Task {
                                                    await performGlobalSearch()
                                                }
                                            }
                                            .onChange(of: appState.globalSearchQuery) { _, newValue in
                                                searchDebounceTask?.cancel()
                                                searchDebounceTask = Task {
                                                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                                                    if !Task.isCancelled {
                                                        await performGlobalSearch()
                                                    }
                                                }
                                            }
                                        
                                        if !appState.globalSearchQuery.isEmpty {
                                            Button {
                                                appState.clearSearch()
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.gray)
                                                    .font(.system(size: 12))
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.2))
                                    )
                                    
                                    // Show search results button when there are results
                                    if !appState.searchResults.isEmpty {
                                        Button {
                                            selectedView = [.searchResults]
                                        } label: {
                                            Text("\(appState.searchResults.totalCount) results")
                                                .font(.system(size: 12))
                                        }
                                    }
                                }
                            }
                        case .playlist(let playlist):
                            PlaylistDetailView(playlist: playlist)
                            .toolbar {
                                ToolbarItemGroup(placement: .automatic) {
                                    // Custom search implementation
                                    HStack(spacing: 4) {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 12))
                                        
                                        TextField("Search", text: $appState.globalSearchQuery)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .font(.system(size: 13))
                                            .frame(width: 200)
                                            .onSubmit {
                                                Task {
                                                    await performGlobalSearch()
                                                }
                                            }
                                            .onChange(of: appState.globalSearchQuery) { _, newValue in
                                                searchDebounceTask?.cancel()
                                                searchDebounceTask = Task {
                                                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                                                    if !Task.isCancelled {
                                                        await performGlobalSearch()
                                                    }
                                                }
                                            }
                                        
                                        if !appState.globalSearchQuery.isEmpty {
                                            Button {
                                                appState.clearSearch()
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.gray)
                                                    .font(.system(size: 12))
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.2))
                                    )
                                    
                                    // Show search results button when there are results
                                    if !appState.searchResults.isEmpty {
                                        Button {
                                            selectedView = [.searchResults]
                                        } label: {
                                            Text("\(appState.searchResults.totalCount) results")
                                                .font(.system(size: 12))
                                        }
                                    }
                                }
                            }
                        case .searchResults:
                            // Show the new SearchResultsView
                            SearchResultsView(
                                onAlbumSelected: { album in
                                    selectedAlbum = album
                                    selectedView = [.albumDetail(album)]
                                }
                            )
                            .toolbar {
                                ToolbarItemGroup(placement: .automatic) {
                                    // Custom search implementation
                                    HStack(spacing: 4) {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 12))
                                        
                                        TextField("Search", text: $appState.globalSearchQuery)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .font(.system(size: 13))
                                            .frame(width: 200)
                                            .onSubmit {
                                                Task {
                                                    await performGlobalSearch()
                                                }
                                            }
                                            .onChange(of: appState.globalSearchQuery) { _, newValue in
                                                searchDebounceTask?.cancel()
                                                searchDebounceTask = Task {
                                                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                                                    if !Task.isCancelled {
                                                        await performGlobalSearch()
                                                    }
                                                }
                                            }
                                        
                                        if !appState.globalSearchQuery.isEmpty {
                                            Button {
                                                appState.clearSearch()
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.gray)
                                                    .font(.system(size: 12))
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.2))
                                    )
                                    
                                    // Show results count on search results page
                                    if !appState.searchResults.isEmpty {
                                        Text("\(appState.searchResults.totalCount) results")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        case .recentlyAdded:
                            RecentlyAddedView(
                                libraryViewModel: libraryViewModel,
                                onAlbumSelected: { album in
                                    selectedAlbum = album
                                    selectedView = [.albumDetail(album)]
                                }
                            )
                            .toolbar {
                                ToolbarItemGroup(placement: .automatic) {
                                    // Custom search implementation
                                    HStack(spacing: 4) {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 12))
                                        
                                        TextField("Search", text: $appState.globalSearchQuery)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .font(.system(size: 13))
                                            .frame(width: 200)
                                            .onSubmit {
                                                Task {
                                                    await performGlobalSearch()
                                                }
                                            }
                                            .onChange(of: appState.globalSearchQuery) { _, newValue in
                                                searchDebounceTask?.cancel()
                                                searchDebounceTask = Task {
                                                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                                                    if !Task.isCancelled {
                                                        await performGlobalSearch()
                                                    }
                                                }
                                            }
                                        
                                        if !appState.globalSearchQuery.isEmpty {
                                            Button {
                                                appState.clearSearch()
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.gray)
                                                    .font(.system(size: 12))
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.2))
                                    )
                                    
                                    // Show search results button when there are results
                                    if !appState.searchResults.isEmpty {
                                        Button {
                                            selectedView = [.searchResults]
                                        } label: {
                                            Text("\(appState.searchResults.totalCount) results")
                                                .font(.system(size: 12))
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        AlbumsView(libraryViewModel: libraryViewModel, onAlbumSelected: { album in
                            selectedAlbum = album
                            selectedView = [.albumDetail(album)]
                        })
                        .toolbar {
                            ToolbarItemGroup(placement: .automatic) {
                                // Custom search implementation
                                HStack(spacing: 4) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 12))
                                    
                                    TextField("Search", text: $appState.globalSearchQuery)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .font(.system(size: 13))
                                        .frame(width: 200)
                                        .onSubmit {
                                            Task {
                                                await performGlobalSearch()
                                            }
                                        }
                                        .onChange(of: appState.globalSearchQuery) { _, newValue in
                                            searchDebounceTask?.cancel()
                                            searchDebounceTask = Task {
                                                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                                                if !Task.isCancelled {
                                                    await performGlobalSearch()
                                                }
                                            }
                                        }
                                    
                                    if !appState.globalSearchQuery.isEmpty {
                                        Button {
                                            appState.clearSearch()
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                                .font(.system(size: 12))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.2))
                                )
                                
                                // Show search results button when there are results
                                if !appState.searchResults.isEmpty {
                                    Button {
                                        selectedView = [.searchResults]
                                    } label: {
                                        Text("\(appState.searchResults.totalCount) results")
                                            .font(.system(size: 12))
                                    }
                                }
                            }
                        }
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
            
            // Setup notification observers for menu commands
            NotificationCenter.default.addObserver(forName: Notification.Name("MenuAddFolder"), object: nil, queue: .main) { _ in
                pickFolder()
            }
            
            NotificationCenter.default.addObserver(forName: Notification.Name("MenuNewPlaylist"), object: nil, queue: .main) { _ in
                showNewPlaylistSheet = true
            }
        }
        .onDisappear {
            // Remove notification observers
            NotificationCenter.default.removeObserver(self, name: Notification.Name("MenuAddFolder"), object: nil)
            NotificationCenter.default.removeObserver(self, name: Notification.Name("MenuNewPlaylist"), object: nil)
        }
    }

    // MARK: - Folder Picker for Music

    /// Opens an NSOpenPanel to pick a folder, then scans audio files.
    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder containing audio files"
        panel.prompt = "Add Folder"
        
        if panel.runModal() == .OK, let selectedFolder = panel.url {
            do {
                // Use the enhanced bookmark storage method for the entire folder hierarchy
                print("Requesting secure access for folder: \(selectedFolder.path)")
                if try BookmarkManager.storeSecureAccessForFolder(at: selectedFolder) {
                    print("Secure access granted for folder: \(selectedFolder.path)")
                    
                    // DEBUG: Print all bookmarks to verify
                    // BookmarkManager.printAllBookmarks()
                    
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
                            libraryViewModel.currentPhase = "Reading audio files..."
                        }
                        
                        // Process each file but no need to store bookmarks again
                        var processedFiles = 0
                        
                        // Process each file and update progress - bookmarks already stored by storeSecureAccessForFolder
                        for fileURL in allFiles {
                            processedFiles += 1
                            
                            // Update progress on the main thread
                            DispatchQueue.main.async {
                                libraryViewModel.progress = Double(processedFiles) / Double(totalFiles)
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
                } else {
                    print("Failed to obtain secure access for folder: \(selectedFolder.path)")
                }
            } catch {
                print("Error processing folder: \(error)")
            }
        }
    }

    private func performGlobalSearch() async {
        // Only perform search if query has at least 3 characters
        guard appState.globalSearchQuery.count >= 3 else {
            // Clear search results if query is too short
            await MainActor.run {
                appState.searchResults = SearchResults()
            }
            return
        }
        
        // Use library view model's search function
        await libraryViewModel.performGlobalSearch(query: appState.globalSearchQuery)
        
        // Once search is complete, check if we have results and show them
        if !appState.globalSearchQuery.isEmpty && !appState.searchResults.isEmpty {
            await MainActor.run {
                // Only navigate if we have a non-empty search query and results
                selectedView = [.searchResults]
            }
        }
    }
}

#Preview {
    ContentView()
}
