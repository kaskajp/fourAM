import SwiftUI
import SwiftData
import AppKit

struct AlbumsView: View {
    @ObservedObject var libraryViewModel: LibraryViewModel
    @ObservedObject private var keyMonitorManager = KeyMonitorManager.shared
    var onAlbumSelected: ((Album) -> Void)? = nil
    var onSetRefreshAction: ((@escaping () -> Void) -> Void)?
    @Environment(\.modelContext) private var modelContext
    @AppStorage("coverImageSize") private var coverImageSize: Double = 120.0
    @State private var searchQuery: String = "" // Search query for filtering albums
    @State private var debouncedSearchQuery: String = ""
    @StateObject private var timerManager = TimerManager()
    @State private var filteredAlbums: [Album] = [] // Filtered albums
    @State private var loadAlbumsTask: Task<Void, Never>?
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
                        .onChange(of: searchQuery) { oldValue, newValue in
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

            if libraryViewModel.isLoadingAlbums {
                ProgressView("Loading albums...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
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
        }
        .onAppear {
            keyMonitorManager.startMonitoring { isSearchFieldFocused }
            loadAlbumsTask = Task {
                await loadAlbums()
            }
            onSetRefreshAction?({
                Task {
                    await loadAlbums()
                }
            })
        }
        .onDisappear {
            keyMonitorManager.stopMonitoring()
            loadAlbumsTask?.cancel()
        }
        .onChange(of: debouncedSearchQuery) { oldValue, newValue in
            filterAlbums()
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
        .navigationTitle("Albums")
    }
    
    private func loadAlbums() async {
        let albums = await libraryViewModel.allAlbums()
        await MainActor.run {
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
    }
    
    private func filterAlbums() {
        loadAlbumsTask?.cancel()
        loadAlbumsTask = Task {
            await loadAlbums()
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
                
                Button("Open in Meta") {
                    openInMeta(album)
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

    private func openInMeta(_ album: Album) {
        // Create a URL for the Meta application
        guard let metaURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.nightbirdsevolve.Meta") else {
            print("Meta app not found by bundle identifier")
            // Fallback to finding Meta by path if bundle ID fails
            let metaAppPath = "/Applications/Meta.app"
            let metaByPathURL = URL(fileURLWithPath: metaAppPath)
            if FileManager.default.fileExists(atPath: metaAppPath) {
                print("Found Meta at: \(metaAppPath)")
                openTracksWithMetaApp(album: album, metaURL: metaByPathURL)
            } else {
                print("Meta app not found at \(metaAppPath)")
            }
            return
        }
        
        openTracksWithMetaApp(album: album, metaURL: metaURL)
    }
    
    private func openTracksWithMetaApp(album: Album, metaURL: URL) {
        // Try to get the first track to open the folder instead of individual files
        guard let firstTrack = album.tracks.first else { return }
        let fullTrackPath = firstTrack.path
        
        guard let topLevelFolderPath = LibraryHelper.findTopLevelFolder(for: fullTrackPath),
              let resolvedFolder = BookmarkManager.resolveBookmark(for: topLevelFolderPath),
              resolvedFolder.startAccessingSecurityScopedResource() else {
            print("Cannot resolve security scope.")
            return
        }
        
        // Make sure to stop accessing the security scoped resource when done
        defer { resolvedFolder.stopAccessingSecurityScopedResource() }
        
        // Get file paths for all tracks in the album
        let filePaths = album.tracks.compactMap { track -> String? in
            let trackPath = track.path
            let relativeSubPath = trackPath.dropFirst(topLevelFolderPath.count)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let fullURL = resolvedFolder.appendingPathComponent(relativeSubPath, isDirectory: false)
            return fullURL.path
        }
        
        // Create a temporary shell script to open the files in Meta
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("open_in_meta.sh")
        
        // Build script content
        var scriptContent = "#!/bin/bash\n"
        scriptContent += "# Open music files in Meta\n"
        scriptContent += "open -a \"\(metaURL.path)\"\n"
        scriptContent += "sleep 1\n" // Give Meta time to launch
        
        // Add each file to be opened
        let escapedFilePaths = filePaths.map { path in
            return "'\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
        }
        scriptContent += "open -a \"\(metaURL.path)\" \(escapedFilePaths.joined(separator: " "))\n"
        
        do {
            // Write the script to a temporary file
            try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            
            // Make the script executable
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
            
            // Execute the script
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = [scriptURL.path]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            
            print("Executing script to open files in Meta")
            try task.run()
            
            // Read output for debugging
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                print("Script output: \(output)")
            }
            
            // Clean up the temporary script
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                try? FileManager.default.removeItem(at: scriptURL)
            }
            
        } catch {
            print("Error executing script: \(error)")
            
            // Fallback to the dialog approach
            let folderURL = resolvedFolder.appendingPathComponent(
                fullTrackPath.dropFirst(topLevelFolderPath.count)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/")),
                isDirectory: false
            ).deletingLastPathComponent()
            
            // Simply launch Meta
            NSWorkspace.shared.open(metaURL)
            
            // Show fallback alert dialog with instructions
            let alert = NSAlert()
            alert.messageText = "Could not automatically open files in Meta"
            alert.informativeText = "Meta has been launched. Please manually open the files:\n\n1. In Meta, select File > Open\n2. Navigate to this folder: \(folderURL.path)\n3. Select all tracks and click Open\n\nFolder path has been copied to clipboard for convenience."
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open Folder in Finder")
            
            // Copy folder path to clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(folderURL.path, forType: .string)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let response = alert.runModal()
                if response == NSApplication.ModalResponse.alertSecondButtonReturn {
                    NSWorkspace.shared.open(folderURL)
                }
            }
        }
    }
}

