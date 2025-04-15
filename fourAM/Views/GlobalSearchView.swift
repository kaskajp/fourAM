import SwiftUI
import SwiftData
import AppKit

struct GlobalSearchView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var libraryViewModel = LibraryViewModel.shared
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isSearchFieldFocused: Bool
    
    @State private var searchTask: Task<Void, Never>?
    @State private var keyboardMonitor: Any?
    @State private var mouseMonitor: Any?
    @State private var showDropdown: Bool = false
    @Binding var selectedView: Set<SelectionValue>
    
    var body: some View {
        // Root view with coordinate space for positioning
        ZStack {
            // Search field - compact version for toolbar
            searchField
                .coordinateSpace(name: "searchField")
                .padding(.bottom, 6)
            
            // Dropdown for search results
            if showDropdown && !appState.globalSearchQuery.isEmpty {
                GeometryReader { proxy in
                    VStack(alignment: .leading) {
                        Spacer().frame(height: 35)
                        
                        Group {
                            if appState.isSearching {
                                ProgressView("Searching...")
                                    .padding()
                                    .frame(width: 300, height: 100)
                            } else if appState.searchResults.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 24))
                                        .foregroundColor(.secondary)
                                    Text("No results found")
                                        .font(.callout)
                                }
                                .frame(width: 300, height: 100)
                            } else {
                                SearchResultsDropdown(
                                    results: appState.searchResults,
                                    selectedView: $selectedView,
                                    onDismiss: {
                                        showDropdown = false
                                    }
                                )
                                .frame(width: 300)
                                .frame(maxHeight: 400)
                            }
                        }
                        .background(Color(.windowBackgroundColor))
                        .cornerRadius(8)
                        .shadow(radius: 5)
                    }
                }
                .zIndex(100)
            }
        }
        .onAppear {
            // Set up keyboard shortcut and mouse monitors
            setupEventMonitors()
        }
        .onDisappear {
            // Clean up monitors
            cleanupEventMonitors()
        }
    }
    
    private var searchField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 12))
            
            TextField("Search", text: $appState.globalSearchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isSearchFieldFocused)
                .font(.system(size: 13))
                .onSubmit {
                    // Only perform search if there are at least 3 characters
                    if appState.globalSearchQuery.count >= 3 {
                        Task {
                            await performSearch()
                        }
                    }
                }
                .onChange(of: appState.globalSearchQuery) { _, newValue in
                    // Show dropdown when typing
                    if newValue.isEmpty {
                        showDropdown = false
                    } else if isSearchFieldFocused {
                        showDropdown = true
                    }
                    
                    // Debounce search and require minimum characters
                    searchTask?.cancel()
                    
                    // Only schedule search task if we have enough characters
                    if newValue.count >= 3 {
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                            if !Task.isCancelled {
                                await performSearch()
                            }
                        }
                    } else {
                        // Clear results if text is too short
                        appState.searchResults = SearchResults()
                    }
                }
                .onChange(of: isSearchFieldFocused) { _, isFocused in
                    // Show or hide dropdown based on focus
                    if isFocused && !appState.globalSearchQuery.isEmpty {
                        showDropdown = true
                    }
                }
            
            if !appState.globalSearchQuery.isEmpty {
                Button {
                    appState.clearSearch()
                    showDropdown = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.2))
        )
        .onTapGesture {
            isSearchFieldFocused = true
        }
    }
    
    private func setupEventMonitors() {
        // Clean up any existing monitors first
        cleanupEventMonitors()
        
        // Set up keyboard shortcut monitor for Cmd+F
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "f" {
                isSearchFieldFocused = true
                return nil // Swallow the event
            }
            return event
        }
        
        // Set up mouse monitor to detect clicks outside search
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            // If dropdown is showing, close it when clicking outside
            if showDropdown {
                DispatchQueue.main.async {
                    showDropdown = false
                }
            }
        }
    }
    
    private func cleanupEventMonitors() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
        
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }
    
    private func performSearch() async {
        // Check minimum character requirement
        guard appState.globalSearchQuery.count >= 3 else {
            // Clear search results if query is too short
            await MainActor.run {
                appState.searchResults = SearchResults()
            }
            return
        }
        
        print("Starting search for: \(appState.globalSearchQuery)")
        // Use library view model's search function
        await libraryViewModel.performGlobalSearch(query: appState.globalSearchQuery)
        print("Search completed. Results: \(appState.searchResults.totalCount)")
        
        // Force UI update by explicitly setting showDropdown
        await MainActor.run {
            if !appState.globalSearchQuery.isEmpty && !appState.searchResults.isEmpty {
                showDropdown = true
            }
        }
    }
}

// A separate view for the dropdown results
struct SearchResultsDropdown: View {
    let results: SearchResults
    @Binding var selectedView: Set<SelectionValue>
    let onDismiss: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Albums header
                if !results.albums.isEmpty {
                    Text("Albums")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // Albums list
                    ForEach(results.albums.prefix(5), id: \.id) { album in
                        Button {
                            selectedView = [.albumDetail(album)]
                            onDismiss()
                        } label: {
                            HStack {
                                OptimizedAlbumArtView(
                                    thumbnailData: album.thumbnail,
                                    albumId: album.id.uuidString,
                                    size: 40
                                )
                                
                                VStack(alignment: .leading) {
                                    Text(album.name)
                                        .font(.system(size: 13))
                                        .lineLimit(1)
                                    
                                    Text(album.albumArtist)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                    }
                    
                    if results.albums.count > 5 {
                        Text("... and \(results.albums.count - 5) more albums")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    
                    Divider()
                }
                
                // Tracks header
                if !results.tracks.isEmpty {
                    Text("Tracks")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // Tracks list
                    ForEach(results.tracks.prefix(5), id: \.id) { track in
                        Button {
                            PlaybackManager.shared.play(
                                track: track,
                                tracks: results.tracks
                            )
                            onDismiss()
                        } label: {
                            HStack {
                                OptimizedAlbumArtView(
                                    thumbnailData: track.thumbnail,
                                    albumId: track.id.uuidString + "-track",
                                    size: 40
                                )
                                
                                VStack(alignment: .leading) {
                                    Text(track.title)
                                        .font(.system(size: 13))
                                        .lineLimit(1)
                                    
                                    Text("\(track.artist) • \(track.album)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Text(track.durationString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                    }
                    
                    if results.tracks.count > 5 {
                        Text("... and \(results.tracks.count - 5) more tracks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
} 