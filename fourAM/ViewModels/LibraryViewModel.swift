import SwiftUI
import SwiftData

class LibraryViewModel: ObservableObject {
    static let shared = LibraryViewModel() // Singleton instance
    @Published var selectedAlbum: Album?
    @Published var tracks: [Track] = []
    @Published var isScanning: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentPhase: String = "Scanning files..."
    @Published var isLoadingAlbums: Bool = false  // New loading state
    @Published var albumCache: [String: Album] = [:]
    @Published var thumbnailCache: ThumbnailCache = ThumbnailCache()
    
    // Add cache for albums
    private var albumsCache: [String: [Album]] = [:]
    private var lastRefreshTime: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    // Add task tracking
    private var currentScanTask: Task<Void, Never>?
    private var currentLoadTask: Task<Void, Never>?
    
    private var modelContext: ModelContext?
    private var fileScanner: FileScanner?
    private var metadataExtractor: MetadataExtractor?
    
    private init() {}
    
    deinit {
        // Cancel any ongoing tasks
        currentScanTask?.cancel()
        currentLoadTask?.cancel()
    }
    
    func selectAlbum(_ album: Album) {
        selectedAlbum = album
    }
    
    func deleteAlbum(_ album: Album, context: ModelContext) {
        // Cancel any ongoing tasks before deleting
        currentScanTask?.cancel()
        currentLoadTask?.cancel()
        
        // 1) For each track in this album, remove it from SwiftData
        for track in album.tracks {
            // We identify each track in SwiftData by its `path` or other unique property
            let targetPath = track.path
            var descriptor = FetchDescriptor<Track>(
                predicate: #Predicate { $0.path == targetPath }
            )
            descriptor.fetchLimit = 1
            
            if let existingTrack = try? context.fetch(descriptor).first {
                context.delete(existingTrack)
            }
        }
        
        // 2) Save changes
        do {
            try context.save()
            
            // 3) Refresh local in-memory array and clear cache
            self.tracks = LibraryHelper.fetchTracks(from: context)
            clearAlbumsCache()
            
            print("Deleted album '\(album.name)' and its tracks from SwiftData.")
        } catch {
            print("Error deleting album: \(error)")
        }
    }
    
    /// A computed list of unique artist names
    var allArtists: [String] {
        let artistSet = Set(tracks.map { $0.artist })
        return artistSet.sorted()
    }

    @MainActor
    private func updateProgress(_ value: Double) {
        self.progress = value
    }
    
    @MainActor
    private func updatePhase(_ phase: String) {
        self.currentPhase = phase
    }
    
    @MainActor
    private func saveTracksToContext(_ tracks: [Track], context: ModelContext) {
        do {
            // Insert tracks
            for track in tracks {
                context.insert(track)
            }
            try context.save()
            
            // Update tracks on main actor
            self.tracks = LibraryHelper.fetchTracks(from: context)
            print("Successfully saved \(tracks.count) new tracks to SwiftData. Total tracks: \(self.tracks.count)")
            
            // Clear cache and force refresh only after tracks are saved
            clearAlbumsCache()
            
            self.progress = 1.0
            self.currentPhase = ""
            self.isScanning = false
        } catch {
            print("Error saving tracks to SwiftData: \(error)")
        }
    }
    
    @MainActor
    private func fetchExistingPaths(context: ModelContext) -> Set<String> {
        do {
            return Set(try context.fetch(FetchDescriptor<Track>()).map { $0.path })
        } catch {
            print("Error fetching existing paths: \(error)")
            return []
        }
    }
    
    /// Asynchronously scan a folder, extract metadata, and save new tracks to SwiftData.
    @MainActor
    func loadLibrary(folderPath: String, context: ModelContext) {
        // Cancel any existing tasks
        currentScanTask?.cancel()
        currentLoadTask?.cancel()
        
        isScanning = true
        progress = 0.0
        currentPhase = "Scanning files..."
        clearAlbumsCache()

        currentLoadTask = Task {
            // Get existing paths before starting the scan
            let existingPaths = self.fetchExistingPaths(context: context)
            
            FileScanner.scanLibraryAsync(
                folderPath: folderPath,
                progressHandler: { [weak self] newProgress in
                    Task { @MainActor in
                        self?.progress = newProgress
                    }
                },
                completion: { [weak self] files in
                    guard let self = self else { return }
                    
                    Task {
                        let totalFiles = files.count
                        var processedFiles = 0
                        let fileProcessingUpdateInterval = 10
                        let semaphore = AsyncSemaphore(limit: 1)
                        var newTracks: [Track] = []
                        let thumbnailCache = ThumbnailCache()
                        
                        await MainActor.run {
                            self.updatePhase("Processing files...")
                            self.progress = 0.0
                        }
                        
                        await withTaskGroup(of: Track?.self) { group in
                            for url in files {
                                if Task.isCancelled { break }
                                
                                group.addTask {
                                    // Create a task to handle semaphore operations
                                    await Task {
                                        await semaphore.wait()
                                        defer { Task { await semaphore.signal() } }
                                        
                                        do {
                                            let audioFile = try await MetadataExtractor.extract(from: url)
                                            
                                            if !existingPaths.contains(url.path) {
                                                if !audioFile.album.isEmpty {
                                                    if let artwork = audioFile.artwork,
                                                       NSImage(data: artwork) != nil {
                                                        if let thumbnail = self.createThumbnail(from: artwork, maxDimension: 300) {
                                                            await self.thumbnailCache.setThumbnail(thumbnail, for: audioFile.album)
                                                        }
                                                    }
                                                }
                                                
                                                return Track(
                                                    path: url.path,
                                                    url: url,
                                                    title: audioFile.title,
                                                    artist: audioFile.artist,
                                                    album: audioFile.album,
                                                    discNumber: audioFile.discNumber,
                                                    albumArtist: audioFile.albumArtist,
                                                    artwork: audioFile.artwork,
                                                    thumbnail: await self.thumbnailCache.getThumbnail(for: audioFile.album),
                                                    trackNumber: audioFile.trackNumber,
                                                    durationString: audioFile.durationString,
                                                    genre: audioFile.genre,
                                                    releaseYear: audioFile.releaseYear,
                                                    additionDate: Date()  // Set date only for new tracks
                                                )
                                            }
                                        } catch {
                                            print("Error processing file \(url): \(error)")
                                        }
                                        return nil
                                    }.value
                                }
                            }
                            
                            for await track in group {
                                if Task.isCancelled { break }
                                
                                if let track = track {
                                    newTracks.append(track)
                                }
                                processedFiles += 1
                                
                                if processedFiles % fileProcessingUpdateInterval == 0 || processedFiles == totalFiles {
                                    let progressValue = Double(processedFiles) / Double(totalFiles)
                                    await MainActor.run {
                                        self.updateProgress(progressValue)
                                    }
                                }
                            }
                        }
                        
                        if !Task.isCancelled {
                            await MainActor.run {
                                self.saveTracksToContext(newTracks, context: context)
                            }
                        }
                    }
                }
            )
        }
    }
    
    @MainActor
    func rescanAlbum(_ album: Album, context: ModelContext) {
        // Ensure the album has at least one track to determine the folder path
        guard let firstTrackPath = album.tracks.first?.path else {
            print("Error: Unable to determine folder path for album '\(album.name)'")
            return
        }

        // Get the parent directory path (album folder)
        let albumFolderPath = (firstTrackPath as NSString).deletingLastPathComponent

        // Get the top level folder path and resolve security scope
        guard let topLevelFolderPath = LibraryHelper.findTopLevelFolder(for: albumFolderPath),
              let resolvedFolder = BookmarkManager.resolveBookmark(for: topLevelFolderPath) else {
            print("Error: Cannot resolve security scope for folder")
            return
        }

        // Start accessing the security-scoped resource
        guard resolvedFolder.startAccessingSecurityScopedResource() else {
            print("Error: Cannot access security-scoped resource")
            return
        }
        defer { resolvedFolder.stopAccessingSecurityScopedResource() }

        // Get the relative path from the top level folder to our target folder
        let relativeSubPath = albumFolderPath.dropFirst(topLevelFolderPath.count)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // Construct the full path, ensuring it starts with a slash for external volumes
        let folderPath = "/" + resolvedFolder.appendingPathComponent(relativeSubPath, isDirectory: true).path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // Clear cache before rescanning
        clearAlbumsCache()
        
        // Delete the album first
        deleteAlbum(album, context: context)
        
        // Start scanning the folder
        isScanning = true
        progress = 0.0
        currentPhase = "Rescanning album..."
        
        currentLoadTask = Task {
            FileScanner.scanLibraryAsync(
                folderPath: folderPath,
                progressHandler: { [weak self] newProgress in
                    Task { @MainActor in
                        self?.progress = newProgress
                    }
                },
                completion: { [weak self] files in
                    guard let self = self else { return }
                    
                    Task {
                        let totalFiles = files.count
                        var processedFiles = 0
                        let fileProcessingUpdateInterval = 10
                        let semaphore = AsyncSemaphore(limit: 1)
                        var newTracks: [Track] = []
                        let thumbnailCache = ThumbnailCache()
                        
                        await MainActor.run {
                            self.updatePhase("Processing files...")
                            self.progress = 0.0
                        }
                        
                        await withTaskGroup(of: Track?.self) { group in
                            for url in files {
                                if Task.isCancelled { break }
                                
                                group.addTask {
                                    await semaphore.wait()
                                    defer { Task { await semaphore.signal() } }
                                    
                                    do {
                                        let audioFile = try await MetadataExtractor.extract(from: url)
                                        
                                        // Process all files in the folder since we're filtering by folder path
                                        if !audioFile.album.isEmpty {
                                            if let artwork = audioFile.artwork,
                                               NSImage(data: artwork) != nil {
                                                if let thumbnail = self.createThumbnail(from: artwork, maxDimension: 300) {
                                                    await thumbnailCache.setThumbnail(thumbnail, for: audioFile.album)
                                                }
                                            }
                                        }
                                        
                                        return Track(
                                            path: url.path,
                                            url: url,
                                            title: audioFile.title,
                                            artist: audioFile.artist,
                                            album: audioFile.album,
                                            discNumber: audioFile.discNumber,
                                            albumArtist: audioFile.albumArtist,
                                            artwork: audioFile.artwork,
                                            thumbnail: await thumbnailCache.getThumbnail(for: audioFile.album),
                                            trackNumber: audioFile.trackNumber,
                                            durationString: audioFile.durationString,
                                            genre: audioFile.genre,
                                            releaseYear: audioFile.releaseYear,
                                            additionDate: Date()  // Set current date when rescanning
                                        )
                                    } catch {
                                        print("Error processing file \(url): \(error)")
                                    }
                                    return nil
                                }
                            }
                            
                            for await track in group {
                                if Task.isCancelled { break }
                                
                                if let track = track {
                                    newTracks.append(track)
                                }
                                processedFiles += 1
                                
                                if processedFiles % fileProcessingUpdateInterval == 0 || processedFiles == totalFiles {
                                    let progressValue = Double(processedFiles) / Double(totalFiles)
                                    await MainActor.run {
                                        self.updateProgress(progressValue)
                                    }
                                }
                            }
                        }
                        
                        if !Task.isCancelled {
                            await MainActor.run {
                                self.saveTracksToContext(newTracks, context: context)
                                self.isScanning = false
                                self.progress = 1.0
                                self.currentPhase = ""
                            }
                        }
                    }
                }
            )
        }
    }
    
    private func createThumbnail(from data: Data, maxDimension: CGFloat) -> Data? {
        // Create an image source from the data
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("Failed to create CGImageSource from data.")
            return nil
        }

        // Options for creating a thumbnail
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailFromImageAlways: true
        ]

        // Generate the thumbnail
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            print("Failed to create thumbnail image.")
            return nil
        }

        // Convert CGImage to JPEG Data
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            print("Failed to create JPEG representation from thumbnail image.")
            return nil
        }

        return jpegData
    }
    
    func refreshTracks(context: ModelContext) {
        self.tracks = LibraryHelper.fetchTracks(from: context)
        print("Tracks refreshed. Count: \(self.tracks.count)")
        clearAlbumsCache() // Clear cache when tracks are refreshed
    }
    
    /// Return all albums for a particular artist, grouped by album name.
    func albums(for artist: String) async -> [Album] {
        // Check cache first
        if let cachedAlbums = albumsCache[artist],
           let lastRefresh = lastRefreshTime,
           Date().timeIntervalSince(lastRefresh) < cacheValidityDuration {
            return cachedAlbums
        }
        
        // Capture necessary values before async work
        let tracksSnapshot = tracks
        
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                isLoadingAlbums = true
                
                let artistTracks = tracksSnapshot.filter { $0.artist == artist }
                let grouped = Dictionary(grouping: artistTracks, by: \.album)
                
                let albums = grouped.map { (albumName, albumTracks) in
                    Album(
                        name: albumName,
                        albumArtist: albumTracks.first?.albumArtist,
                        artwork: albumTracks.first?.artwork,
                        thumbnail: albumTracks.first?.thumbnail,
                        tracks: albumTracks,
                        releaseYear: albumTracks.first?.releaseYear ?? 0,
                        genre: albumTracks.first?.genre ?? ""
                    )
                }
                .sorted { $0.name < $1.name }
                
                // Update cache
                albumsCache[artist] = albums
                lastRefreshTime = Date()
                isLoadingAlbums = false
                
                continuation.resume(returning: albums)
            }
        }
    }
    
    /// Return all albums across the entire library.
    func allAlbums() async -> [Album] {
        // Check cache first
        if let cachedAlbums = albumsCache["_all"],
           let lastRefresh = lastRefreshTime,
           Date().timeIntervalSince(lastRefresh) < cacheValidityDuration {
            print("Using cached albums. Count: \(cachedAlbums.count)")
            return cachedAlbums
        }
        
        // Capture necessary values before async work
        let tracksSnapshot = tracks
        print("Starting album build process with \(tracksSnapshot.count) tracks")
        
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                isLoadingAlbums = true
                
                let grouped = Dictionary(grouping: tracksSnapshot, by: \.album)
                print("Grouped \(grouped.count) albums")
                var albums: [Album] = []
                
                for (albumName, albumTracks) in grouped {
                    // Skip empty albums
                    if albumName.isEmpty {
                        print("Skipping album with empty name")
                        continue
                    }
                    
                    let coverArt = albumTracks.first?.artwork
                    let thumbnail = albumTracks.first?.thumbnail
                    albums.append(Album(
                        name: albumName,
                        albumArtist: albumTracks.first?.albumArtist ?? "Unknown Artist",
                        artwork: coverArt,
                        thumbnail: thumbnail,
                        tracks: albumTracks,
                        releaseYear: albumTracks.first?.releaseYear ?? 0,
                        genre: albumTracks.first?.genre ?? ""
                    ))
                }
                
                let sortedAlbums = albums.sorted { $0.name < $1.name }
                print("Created \(sortedAlbums.count) album objects")
                
                // Update cache
                albumsCache["_all"] = sortedAlbums
                lastRefreshTime = Date()
                isLoadingAlbums = false
                
                continuation.resume(returning: sortedAlbums)
            }
        }
    }
    
    // Add method to clear cache if needed
    func clearAlbumsCache() {
        albumsCache.removeAll()
        lastRefreshTime = nil
    }
    
    // Add method to regenerate album art thumbnails
    @MainActor
    func regenerateAlbumArt(context: ModelContext) async {
        isLoadingAlbums = true
        
        let thumbnailCache = ThumbnailCache.shared
        let tracksSnapshot = tracks // Capture tracks before async work
        
        // Process each track
        for track in tracksSnapshot {
            if let artwork = track.artwork,
               NSImage(data: artwork) != nil {
                if let thumbnail = createThumbnail(from: artwork, maxDimension: 300) {
                    await thumbnailCache.setThumbnail(thumbnail, for: track.album)
                    track.thumbnail = thumbnail
                    try? context.save() // Save each update individually
                }
            }
        }
        
        clearAlbumsCache()
        refreshTracks(context: context)
        isLoadingAlbums = false
    }
    
    func incrementPlayCount(for track: Track, context: ModelContext) {
        do {
            track.playCount += 1
            try context.save()
        } catch {
            print("Failed to increment play count: \(error)")
        }
    }
    
    func resetPlayCountForTrack(for track: Track, context: ModelContext) {
        do {
            track.playCount = 0
            try context.save()
        } catch {
            print("Failed to reset play count: \(error)")
        }
    }
    
    // Global search functionality
    @MainActor
    func performGlobalSearch(query: String) async {
        guard !query.isEmpty else {
            AppState.shared.clearSearch()
            return
        }
        
        AppState.shared.isSearching = true
        let lowercaseQuery = query.lowercased()
        
        // Search for albums
        let allAlbumsList = await allAlbums()
        let matchingAlbums = allAlbumsList.filter { album in
            album.name.lowercased().contains(lowercaseQuery) ||
            album.albumArtist.lowercased().contains(lowercaseQuery) ||
            album.genre.lowercased().contains(lowercaseQuery)
        }
        
        // Search for tracks
        let matchingTracks = tracks.filter { track in
            track.title.lowercased().contains(lowercaseQuery) ||
            track.artist.lowercased().contains(lowercaseQuery) ||
            track.album.lowercased().contains(lowercaseQuery) ||
            (track.genre?.lowercased().contains(lowercaseQuery) ?? false)
        }
        
        // Update the search results
        let results = SearchResults(
            albums: matchingAlbums,
            tracks: matchingTracks
        )
        
        // Update AppState with results
        AppState.shared.searchResults = results
        AppState.shared.isSearching = false
        
        print("Global search for '\(query)' found \(matchingAlbums.count) albums and \(matchingTracks.count) tracks")
    }
}
