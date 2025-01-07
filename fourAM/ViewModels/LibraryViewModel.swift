//
//  LibraryViewModel.swift
//  fourAM
//
//  Created by Jonas on 2025-01-05.
//

import SwiftUI
import SwiftData

class LibraryViewModel: ObservableObject {
    @Published var tracks: [Track] = []
    
    /// Keep track of scanning progress (0.0–1.0)
    @Published var progress: Double = 0.0
    @Published var currentPhase: String = "Scanning files..."
    
    /// Indicates whether we’re currently scanning
    @Published var isScanning: Bool = false
    
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
                        let totalFiles = files.count
                        var processedFiles = 0
                        var newTracks: [Track] = [] // Collect new tracks in memory

                        // Transition to the "Processing files..." phase
                        DispatchQueue.main.async {
                            self.currentPhase = "Processing files..."
                            self.progress = 0.0 // Reset progress to 0
                        }

                        // Process files (metadata extraction + checking for duplicates)
                        for url in files {
                            let audioFile = MetadataExtractor.extract(from: url)

                            // Check if a track with this path already exists in SwiftData
                            var descriptor = FetchDescriptor<Track>(
                                predicate: #Predicate { $0.path == url.path }
                            )
                            descriptor.fetchLimit = 1

                            let existingTrack = try? context.fetch(descriptor).first
                            if existingTrack == nil {
                                // Prepare a new Track instance
                                let newTrack = Track(
                                    path: url.path,
                                    title: audioFile.title,
                                    artist: audioFile.artist,
                                    album: audioFile.album,
                                    artwork: audioFile.artwork,
                                    trackNumber: audioFile.trackNumber,
                                    durationString: audioFile.durationString
                                )
                                newTracks.append(newTrack)
                            }

                            // Update progress (metadata extraction is now the second phase)
                            processedFiles += 1
                            DispatchQueue.main.async {
                                self.progress = Double(processedFiles) / Double(totalFiles)
                            }
                        }

                        // Insert all new tracks into SwiftData in a single batch
                        DispatchQueue.main.async {
                            do {
                                for track in newTracks {
                                    context.insert(track)
                                }
                                try context.save()

                                // Refresh in-memory tracks on the main thread
                                self.tracks = LibraryHelper.fetchTracks(from: context)
                                print("Successfully saved \(newTracks.count) new tracks to SwiftData.")
                            } catch {
                                print("Error saving tracks to SwiftData: \(error)")
                            }

                            // Mark scanning as finished
                            self.progress = 1.0 // Ensure progress reaches 100%
                            self.currentPhase = "" // Clear phase label
                            self.isScanning = false
                        }
                    }
                }
            )
        }
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
            albums.append(Album(name: albumName, albumArtist: albumTracks.first?.albumArtist, artwork: coverArt, tracks: albumTracks))
        }

        return albums.sorted { $0.name < $1.name }
    }
}
