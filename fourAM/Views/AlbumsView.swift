import SwiftUI
import SwiftData
import AppKit

struct ScrollPositionPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct AlbumsContainerView: View {
    @ObservedObject var libraryViewModel: LibraryViewModel
    @ObservedObject private var keyMonitorManager = KeyMonitorManager.shared
    var onAlbumSelected: ((Album) -> Void)? = nil
    var onSetRefreshAction: ((@escaping () -> Void) -> Void)?
    @Environment(\.modelContext) private var modelContext
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            // Keep AlbumsView alive in the background
            AlbumsView(
                libraryViewModel: libraryViewModel,
                onAlbumSelected: onAlbumSelected,
                onSetRefreshAction: onSetRefreshAction,
                isContainerVisible: isVisible
            )
            .opacity(isVisible ? 1 : 0)
            .allowsHitTesting(isVisible)
            
            // Show/hide based on visibility
            if !isVisible {
                Color.clear
                    .contentShape(Rectangle())
            }
        }
        .onAppear {
            // Use a short delay to allow animation to look smoother
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isVisible = true
            }
        }
        .onDisappear {
            isVisible = false
        }
    }
}

struct AlbumsView: View {
    @ObservedObject var libraryViewModel: LibraryViewModel
    @ObservedObject private var keyMonitorManager = KeyMonitorManager.shared
    var onAlbumSelected: ((Album) -> Void)? = nil
    var onSetRefreshAction: ((@escaping () -> Void) -> Void)?
    var isContainerVisible: Bool = true
    @Environment(\.modelContext) private var modelContext
    @AppStorage("coverImageSize") private var coverImageSize: Double = 120.0
    @State private var albums: [Album] = [] // All albums
    @State private var loadAlbumsTask: Task<Void, Never>?
    @State private var scrollOffset: CGFloat = 0
    @State private var isRestoringScrollPosition = false
    @State private var hasInitialLoad = false
    @State private var isViewReady = false
    @State private var isSettingScrollPosition = false
    
    var body: some View {
        VStack {
            if libraryViewModel.isLoadingAlbums || (isRestoringScrollPosition && albums.isEmpty) {
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
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ScrollPositionPreferenceKey.self,
                            value: geometry.frame(in: .global).minY
                        )
                    }
                    .frame(height: 0)
                    
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
                                        await loadAlbums()
                                    }
                                },
                                modelContext: modelContext,
                                libraryViewModel: libraryViewModel
                            )
                        }
                    }
                    .padding()
                }
                // Hide content while positioning and show only when ready and container is visible
                .opacity((isViewReady && !isSettingScrollPosition) ? 1 : 0)
                .onPreferenceChange(ScrollPositionPreferenceKey.self) { value in
                    if let scrollView = NSScrollView.current {
                        let currentOffset = scrollView.contentView.bounds.origin.y
                        scrollOffset = currentOffset
                    }
                }
                .onChange(of: isContainerVisible) { oldValue, newValue in
                    if newValue && !oldValue {
                        // Container became visible, restore scroll position
                        restoreScrollPosition()
                    }
                }
                .onAppear {
                    // Only restore scroll position if we appear and container is visible
                    if isContainerVisible {
                        restoreScrollPosition()
                    }
                }
            }
        }
        .onAppear {
            // Only start as not ready if we need to load albums
            isViewReady = !albums.isEmpty && !isSettingScrollPosition
            
            if !hasInitialLoad {
                hasInitialLoad = true
                isRestoringScrollPosition = true
                loadAlbumsTask = Task {
                    await loadAlbums()
                }
            }
            onSetRefreshAction?({
                Task {
                    await loadAlbums()
                }
            })
        }
        .onDisappear {
            loadAlbumsTask?.cancel()
            if let scrollView = NSScrollView.current {
                let currentOffset = scrollView.contentView.bounds.origin.y
                UserDefaults.standard.set(currentOffset, forKey: "lastScrollOffset")
            }
        }
        .onChange(of: libraryViewModel.tracks) { oldValue, newValue in
            // Only reload if the tracks actually changed and we've done initial load
            if oldValue != newValue && hasInitialLoad {
                loadAlbumsTask?.cancel()
                loadAlbumsTask = Task {
                    await loadAlbums()
                }
            }
        }
        .navigationTitle("Albums")
    }
    
    private func restoreScrollPosition() {
        Task { @MainActor in
            // Only restore scroll position if we already have albums loaded
            if !albums.isEmpty {
                // Set flag to hide content during positioning
                isSettingScrollPosition = true
                isRestoringScrollPosition = true
                
                // Wait for content to be ready
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds (reduced time)
                
                if let savedOffset = UserDefaults.standard.object(forKey: "lastScrollOffset") as? CGFloat {
                    if let scrollView = NSScrollView.current {
                        scrollView.contentView.scroll(to: NSPoint(x: 0, y: savedOffset))
                        
                        // Wait for a frame to ensure the scroll position is applied
                        try? await Task.sleep(nanoseconds: 16_666_666) // 1/60th of a second
                    }
                }
                
                // Content is ready to show
                isSettingScrollPosition = false
                isViewReady = true
                isRestoringScrollPosition = false
            } else {
                isViewReady = true
            }
        }
    }
    
    private func loadAlbums() async {
        let allAlbums = await libraryViewModel.allAlbums()
        
        await MainActor.run {
            albums = allAlbums
            isRestoringScrollPosition = false
            
            // Wait a moment before showing to ensure layout is complete
            Task {
                try? await Task.sleep(nanoseconds: 16_666_666) // 1/60th of a second
                isViewReady = true
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
                // Use optimized image view instead of creating NSImage in the render path
                if album.thumbnail != nil {
                    OptimizedAlbumArtView(
                        thumbnailData: album.thumbnail,
                        albumId: album.id.uuidString,
                        size: coverImageSize
                    )
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
                openAlbumFolderInMeta(album: album, metaURL: metaByPathURL)
            } else {
                print("Meta app not found at \(metaAppPath)")
            }
            return
        }
        
        openAlbumFolderInMeta(album: album, metaURL: metaURL)
    }
    
    private func openAlbumFolderInMeta(album: Album, metaURL: URL) {
        // Get the first track to find the folder
        guard let firstTrack = album.tracks.first else { return }
        let fullTrackPath = firstTrack.path
        
        guard let topLevelFolderPath = LibraryHelper.findTopLevelFolder(for: fullTrackPath) else {
            print("Error: Cannot find top level folder for path \(fullTrackPath)")
            showFolderPermissionError()
            return
        }
        
        guard let resolvedFolder = BookmarkManager.resolveBookmark(for: topLevelFolderPath) else {
            print("Error: Cannot resolve bookmark for folder \(topLevelFolderPath)")
            
            // Attempt to fix the bookmark by re-adding
            tryToAddPermissionsForAlbum(album)
            return
        }
        
        // Start accessing security scoped resource
        guard resolvedFolder.startAccessingSecurityScopedResource() else {
            print("Error: Cannot access security scoped resource for folder \(topLevelFolderPath)")
            
            // Attempt to fix the bookmark by re-adding
            tryToAddPermissionsForAlbum(album)
            return
        }
        
        // Find the album folder path 
        let relativeSubPath = fullTrackPath.dropFirst(topLevelFolderPath.count)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let trackURL = resolvedFolder.appendingPathComponent(relativeSubPath, isDirectory: false)
        let albumFolderURL = trackURL.deletingLastPathComponent()
        
        print("Opening album folder in Meta: \(albumFolderURL.path)")
        
        // Create temporary bookmark for folder access
        do {
            try BookmarkManager.storeBookmark(for: albumFolderURL)
            
            // First launch Meta
            NSWorkspace.shared.open(metaURL)
            
            // Then wait a moment for Meta to launch fully
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                do {
                    // Ensure we can open the folder with full permissions
                    if let folderBookmark = BookmarkManager.resolveBookmark(for: albumFolderURL.path), 
                       folderBookmark.startAccessingSecurityScopedResource() {
                        
                        // Create configuration to activate Meta when opening
                        let configuration = NSWorkspace.OpenConfiguration()
                        configuration.activates = true
                        
                        // Open the album folder directly in Meta
                        NSWorkspace.shared.open([folderBookmark], withApplicationAt: metaURL, configuration: configuration)
                        
                        // Stop accessing the security scoped resource after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            folderBookmark.stopAccessingSecurityScopedResource()
                            resolvedFolder.stopAccessingSecurityScopedResource()
                        }
                    } else {
                        // Fallback to Finder if Meta can't access the folder
                        print("Error: Meta cannot access folder \(albumFolderURL.path)")
                        self.showFolderPermissionError()
                        resolvedFolder.stopAccessingSecurityScopedResource()
                    }
                } catch {
                    print("Error opening folder in Meta: \(error)")
                    resolvedFolder.stopAccessingSecurityScopedResource()
                    self.showFolderPermissionError()
                }
            }
        } catch {
            print("Error creating bookmark for album folder: \(error)")
            resolvedFolder.stopAccessingSecurityScopedResource()
            showFolderPermissionError()
        }
    }
    
    // Helper function to show folder permission error with Finder fallback
    private func showFolderPermissionError() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Folder Access Error"
            alert.informativeText = "4AM doesn't have permission to access this folder in Meta. Would you like to open it in Finder instead?"
            alert.addButton(withTitle: "Open in Finder")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn && 
               album.tracks.first != nil {
                // Open in Finder as fallback
                self.showAlbumInFinder(album)
            }
        }
    }
    
    // Helper function to try to add permissions for an album
    private func tryToAddPermissionsForAlbum(_ album: Album) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Folder Permission Required"
            alert.informativeText = "4AM needs permission to access the folder containing this album. Would you like to grant access now?"
            alert.addButton(withTitle: "Grant Access")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn {
                // Show open panel to get user to select the folder again
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.allowsMultipleSelection = false
                panel.message = "Select the folder containing the album '\(album.name)'"
                
                if panel.runModal() == .OK, let selectedFolder = panel.url {
                    do {
                        // Store bookmark with enhanced permissions and check the result
                        let permissionsGranted = try BookmarkManager.storeSecureAccessForFolder(at: selectedFolder)
                        
                        if permissionsGranted {
                            print("Successfully granted permissions for folder: \(selectedFolder.path)")
                            
                            // Try opening again after permissions granted
                            let metaURLFromBundle = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.nightbirdsevolve.Meta")
                            let metaURL = metaURLFromBundle ?? URL(fileURLWithPath: "/Applications/Meta.app")
                            
                            // Check if the Meta app exists at the path
                            if FileManager.default.fileExists(atPath: metaURL.path) {
                                self.openAlbumFolderInMeta(album: album, metaURL: metaURL)
                            } else {
                                print("Meta app not found at path: \(metaURL.path)")
                            }
                        } else {
                            print("Failed to obtain permissions for folder: \(selectedFolder.path)")
                            // Show an error message
                            let failureAlert = NSAlert()
                            failureAlert.messageText = "Permission Error"
                            failureAlert.informativeText = "Could not obtain permissions for the selected folder."
                            failureAlert.runModal()
                        }
                    } catch {
                        print("Error granting folder access: \(error)")
                        // Show the error to the user
                        let errorAlert = NSAlert()
                        errorAlert.messageText = "Permission Error"
                        errorAlert.informativeText = "An error occurred while trying to access the folder: \(error.localizedDescription)"
                        errorAlert.runModal()
                    }
                }
            }
        }
    }
}

extension NSScrollView {
    static var current: NSScrollView? {
        if let window = NSApp.keyWindow,
           let contentView = window.contentView {
            // Try to find the scroll view in the view hierarchy
            func findScrollView(in view: NSView) -> NSScrollView? {
                if let scrollView = view as? NSScrollView {
                    // Only return the scroll view if it's wide enough to be the main content
                    if scrollView.frame.width > 300 {
                        return scrollView
                    }
                }
                for subview in view.subviews {
                    if let found = findScrollView(in: subview) {
                        return found
                    }
                }
                return nil
            }
            return findScrollView(in: contentView)
        }
        return nil
    }
}

