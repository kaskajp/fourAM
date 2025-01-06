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
            self.fetchTracks(context: context)
            
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

        FileScanner.scanLibraryAsync(
            folderPath: folderPath,
            progressHandler: { newProgress in
                // This closure is dispatched on the main thread by FileScanner
                self.progress = newProgress
            },
            completion: { files in
                // Now we have our array of [URL] after scanning completes
                for url in files {
                    let audioFile = MetadataExtractor.extract(from: url)
                    
                    // Check if a track with this path already exists in SwiftData
                    var descriptor = FetchDescriptor<Track>(
                        predicate: #Predicate { $0.path == url.path }
                    )
                    descriptor.fetchLimit = 1
                    
                    let existingTrack = try? context.fetch(descriptor).first
                    if existingTrack == nil {
                        // Insert a new Track
                        let newTrack = Track(
                            path: url.path,
                            title: audioFile.title,
                            artist: audioFile.artist,
                            album: audioFile.album,
                            artwork: audioFile.artwork,
                            trackNumber: audioFile.trackNumber,
                            durationString: audioFile.durationString
                        )
                        context.insert(newTrack)
                    }
                }
                
                // Save all new tracks and refresh our in-memory list
                do {
                    try context.save()
                    self.fetchTracks(context: context)
                    print("Successfully saved tracks to SwiftData, \(files.count) files")
                } catch {
                    print("Error saving tracks to SwiftData: \(error)")
                }
                
                // Mark the scanning operation as finished
                self.isScanning = false
            }
        )
    }
    
    /// Fetch all tracks from SwiftData into our in-memory `tracks` array.
    func fetchTracks(context: ModelContext) {
        do {
            let request = FetchDescriptor<Track>()
            let results = try context.fetch(request)
            self.tracks = results
        } catch {
            print("Error fetching tracks: \(error)")
            self.tracks = []
        }
    }
    
    /// Return all albums for a particular artist, grouped by album name.
    func albums(for artist: String) -> [Album] {
        let artistTracks = tracks.filter { $0.artist == artist }
        let grouped = Dictionary(grouping: artistTracks, by: \.album)

        return grouped.map { (albumName, albumTracks) in
            Album(
                name: albumName,
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
            albums.append(Album(name: albumName, artwork: coverArt, tracks: albumTracks))
        }

        return albums.sorted { $0.name < $1.name }
    }
}
