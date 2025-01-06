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
    
    var allArtists: [String] {
        // Collect all artists, remove duplicates, then sort
        let artistSet = Set(tracks.map { $0.artist })
        return artistSet.sorted()
    }

    /// Scan a folder, extract metadata, and save new tracks to SwiftData.
    func loadLibrary(folderPath: String, context: ModelContext) {
        // 1) Scan for audio URLs
        let urls = FileScanner.scanLibrary(folderPath: folderPath)
        
        for url in urls {
            // 2) Extract metadata from each file
            let audioFile = MetadataExtractor.extract(from: url)
            
            // 3) Check if track with this path already exists:
            var descriptor = FetchDescriptor<Track>(
                predicate: #Predicate { $0.path == url.path }
            )
            descriptor.fetchLimit = 1

            let existingTrack = try? context.fetch(descriptor).first
            
            // 4) If not found, create a new Track and insert it
            if existingTrack == nil {
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
        
        // 5) Save changes to persist them
        do {
            try context.save()
            fetchTracks(context: context)
        } catch {
            print("Error saving tracks to SwiftData: \(error)")
        }
    }
    
    /// Fetch all tracks from SwiftData to display in memory.
    func fetchTracks(context: ModelContext) {
        do {
            // We fetch all tracks for now; you can add sorting or filtering
            let request = FetchDescriptor<Track>()
            let results = try context.fetch(request)
            self.tracks = results
        } catch {
            print("Error fetching tracks: \(error)")
            self.tracks = []
        }
    }
    
    func albums(for artist: String) -> [Album] {
        let artistTracks = tracks.filter { $0.artist == artist }
        let grouped = Dictionary(grouping: artistTracks, by: \.album)

        return grouped.map { (albumName, albumTracks) in
            Album(name: albumName,
                  artwork: albumTracks.first?.artwork,
                  tracks: albumTracks)
        }
        .sorted { $0.name < $1.name }
    }
    
    func allAlbums() -> [Album] {
        let grouped = Dictionary(grouping: tracks, by: \.album)
        var albums: [Album] = []

        for (albumName, tracks) in grouped {
            // Use the first track's artwork for the album, or nil if none
            let coverArt = tracks.first?.artwork
            albums.append(Album(name: albumName, artwork: coverArt, tracks: tracks))
        }

        // Sort by album name
        return albums.sorted { $0.name < $1.name }
    }
}
