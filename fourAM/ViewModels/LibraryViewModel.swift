//
//  LibraryViewModel.swift
//  fourAM
//
//  Created by Jonas on 2025-01-05.
//

import SwiftUI
import SwiftData

class LibraryViewModel: ObservableObject {
    static let shared = LibraryViewModel() // Singleton instance
    @Published var tracks: [Track] = []
    @Published var isScanning: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentPhase: String = "Scanning files..."
    
    private init() {}
    
    func deleteAlbum(_ album: Album, context: ModelContext) {
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
            
            // 3) Refresh local in-memory array
            self.tracks = LibraryHelper.fetchTracks(from: context)
            
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

    /// Asynchronously scan a folder, extract metadata, and save new tracks to SwiftData.
    func loadLibrary(folderPath: String, context: ModelContext) {
        isScanning = true
        progress = 0.0
        currentPhase = "Scanning files..."

        // Allow the UI to update before starting the scanning process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            FileScanner.scanLibraryAsync(
                folderPath: folderPath,
                progressHandler: { newProgress in
                    // Update progress during file scanning (50% max)
                    DispatchQueue.main.async {
                        self.progress = newProgress // Scanning contributes to the first phase
                    }
                },
                completion: { files in
                    DispatchQueue.global(qos: .userInitiated).async {
                        Task {
                            let totalFiles = files.count
                            var processedFiles = 0
                            let fileProcessingUpdateInterval = 10 // Only update the UI every 50 processed files
                            let semaphore = AsyncSemaphore(limit: 1) // Limit to 2 concurrent tasks
                            var newTracks: [Track] = []
                            
                            let existingPaths = Set(try context.fetch(FetchDescriptor<Track>()).map { $0.path })
                            
                            DispatchQueue.main.async {
                                self.currentPhase = "Processing files..."
                                self.progress = 0.0
                            }
                            
                            await withTaskGroup(of: Track?.self) { group in
                                let thumbnailCache = ThumbnailCache() // Use the actor for thread-safe access
                                
                                for url in files {
                                    group.addTask {
                                        // print("Waiting for semaphore: \(url.path)")
                                        await semaphore.wait() // Wait for an available slot
                                        defer {
                                            Task { await semaphore.signal() } // Release the slot asynchronously
                                        }
                                        
                                        do {
                                            let audioFile = try await MetadataExtractor.extract(from: url)
                                            
                                            if !existingPaths.contains(url.path) {
                                                // Check if this album already has a thumbnail
                                                if await thumbnailCache.getThumbnail(for: audioFile.album) == nil,
                                                   let artwork = audioFile.artwork {
                                                    if let thumbnail = self.createThumbnail(from: artwork, maxDimension: 300) {
                                                        await thumbnailCache.setThumbnail(thumbnail, for: audioFile.album)
                                                    } else {
                                                        print("Thumbnail generation failed for album: \(audioFile.album)")
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
                                                    durationString: audioFile.durationString
                                                )
                                            }
                                        } catch {
                                            print("Error processing file \(url): \(error)")
                                        }
                                        return nil
                                    }
                                }
                                
                                for await track in group {
                                    if let track = track {
                                        newTracks.append(track)
                                    }
                                    processedFiles += 1
                                    
                                    // Throttle initial updates and logging
                                    if processedFiles % fileProcessingUpdateInterval == 0 || processedFiles == totalFiles {
                                        DispatchQueue.main.async {
                                            self.progress = Double(processedFiles) / Double(totalFiles)
                                        }
                                    }
                                }
                            }
                            
                            DispatchQueue.main.async {
                                do {
                                    for track in newTracks {
                                        context.insert(track)
                                    }
                                    do {
                                        try context.save()
                                    } catch {
                                        print("Error saving tracks to SwiftData: \(error)")
                                    }
                                    
                                    self.tracks = LibraryHelper.fetchTracks(from: context)
                                    print("Successfully saved \(newTracks.count) new tracks to SwiftData.")
                                } catch {
                                    print("Error saving tracks to SwiftData: \(error)")
                                }
                                
                                self.progress = 1.0
                                self.currentPhase = ""
                                self.isScanning = false
                            }
                        }
                    }
                }
            )
        }
    }
    
    private func createThumbnail(from data: Data, maxDimension: CGFloat) -> Data? {
        print("Creating thumbnail...")
        guard let image = NSImage(data: data) else {
            print("Invalid image data for thumbnail creation.")
            return nil
        }
        
        let targetSize = NSSize(width: maxDimension, height: maxDimension)
        let resizedImage = NSImage(size: targetSize)
        
        resizedImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        resizedImage.unlockFocus()
        
        guard let imageData = resizedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let compressedData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            print("Failed to create thumbnail image data.")
            return nil
        }
        
        return compressedData
    }
    
    func refreshTracks(context: ModelContext) {
        self.tracks = LibraryHelper.fetchTracks(from: context)
        print("Tracks refreshed. Count: \(self.tracks.count)")
    }
    
    /// Return all albums for a particular artist, grouped by album name.
    func albums(for artist: String) -> [Album] {
        let artistTracks = tracks.filter { $0.artist == artist }
        let grouped = Dictionary(grouping: artistTracks, by: \.album)

        return grouped.map { (albumName, albumTracks) in
            Album(
                name: albumName,
                albumArtist: albumTracks.first?.albumArtist,
                artwork: albumTracks.first?.artwork,
                thumbnail: albumTracks.first?.thumbnail,
                tracks: albumTracks
            )
        }
        .sorted { $0.name < $1.name }
    }
    
    /// Return all albums across the entire library.
    func allAlbums() -> [Album] {
        let grouped = Dictionary(grouping: tracks, by: \.album)
        var albums: [Album] = []

        for (albumName, albumTracks) in grouped {
            let coverArt = albumTracks.first?.artwork
            let thumbnail = albumTracks.first?.thumbnail
            albums.append(Album(name: albumName, albumArtist: albumTracks.first?.albumArtist, artwork: coverArt, thumbnail: thumbnail, tracks: albumTracks))
        }

        return albums.sorted { $0.name < $1.name }
    }
}
