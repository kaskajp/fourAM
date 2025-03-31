import SwiftUI
import AVFoundation

actor MetadataCache {
    private var cache: [String: Track] = [:]
    private let maxCacheSize = 1000
    
    func get(for path: String) -> Track? {
        return cache[path]
    }
    
    func set(_ track: Track, for path: String) {
        if cache.count >= maxCacheSize {
            // Remove oldest entry
            cache.removeValue(forKey: cache.keys.first ?? "")
        }
        cache[path] = track
    }
    
    func clear() {
        cache.removeAll()
    }
}

struct MetadataExtractor {
    private static let cache = MetadataCache()
    private static let processingQueue = DispatchQueue(label: "com.fourAM.metadataProcessing", attributes: .concurrent)
    
    static func extract(from url: URL) async throws -> Track {
        // Check cache first
        if let cachedTrack = await cache.get(for: url.path) {
            return cachedTrack
        }
        
        // Create a task group for concurrent metadata extraction
        return try await withThrowingTaskGroup(of: Track.self) { group in
            // Task 1: Extract metadata using TagLib
            group.addTask {
                let metadata = TagLibWrapper.extractMetadata(from: url)
                
                // Create track with fallbacks for all fields
                let track = Track(
                    path: url.path,
                    url: url,
                    title: metadata["title"] as? String ?? url.lastPathComponent,
                    artist: metadata["artist"] as? String ?? "Unknown Artist",
                    album: metadata["album"] as? String ?? "Unknown Album",
                    discNumber: metadata["disc number"] as? Int ?? -1,
                    albumArtist: metadata["album artist"] as? String ?? "Unknown Album Artist",
                    artwork: metadata["artwork"] as? Data,
                    trackNumber: metadata["track number"] as? Int ?? -1,
                    durationString: "0:00", // Will be updated later
                    genre: metadata["genre"] as? String ?? "Unknown Genre",
                    releaseYear: metadata["releaseYear"] as? Int ?? 0
                )
                
                // Verify we have at least a title
                if track.title.isEmpty {
                    print("Warning: Empty title for \(url.path), using filename")
                    track.title = url.lastPathComponent
                }
                
                return track
            }
            
            // Task 2: Extract duration and artwork from AVAsset
            group.addTask {
                do {
                    let asset = AVAsset(url: url)
                    let durationSeconds = try await CMTimeGetSeconds(asset.load(.duration))
                    let durationString = formatTime(durationSeconds)
                    
                    // Try to get artwork from common metadata
                    var artwork: Data?
                    let commonMetadata = try await asset.load(.commonMetadata)
                    let metadataValues = try await loadMetadataValues(from: commonMetadata)
                    artwork = metadataValues["artwork"] as? Data
                    
                    return Track(
                        path: url.path,
                        url: url,
                        title: url.lastPathComponent,
                        artist: "Unknown Artist",
                        album: "Unknown Album",
                        discNumber: -1,
                        albumArtist: "Unknown Album Artist",
                        artwork: artwork,
                        trackNumber: -1,
                        durationString: durationString,
                        genre: "Unknown Genre",
                        releaseYear: 0
                    )
                } catch {
                    print("Error extracting duration for \(url.path): \(error)")
                    // Return a basic track with just the filename
                    return Track(
                        path: url.path,
                        url: url,
                        title: url.lastPathComponent,
                        artist: "Unknown Artist",
                        album: "Unknown Album",
                        discNumber: -1,
                        albumArtist: "Unknown Album Artist",
                        artwork: nil,
                        trackNumber: -1,
                        durationString: "0:00",
                        genre: "Unknown Genre",
                        releaseYear: 0
                    )
                }
            }
            
            // Combine results
            var finalTrack: Track?
            for try await track in group {
                if finalTrack == nil {
                    finalTrack = track
                } else {
                    // Merge metadata, preferring TagLib data over AVAsset data
                    finalTrack = Track(
                        path: track.path,
                        url: track.url,
                        title: finalTrack?.title ?? track.title,
                        artist: finalTrack?.artist ?? track.artist,
                        album: finalTrack?.album ?? track.album,
                        discNumber: finalTrack?.discNumber ?? track.discNumber,
                        albumArtist: finalTrack?.albumArtist ?? track.albumArtist,
                        artwork: finalTrack?.artwork ?? track.artwork,
                        trackNumber: finalTrack?.trackNumber ?? track.trackNumber,
                        durationString: track.durationString, // Use AVAsset duration
                        genre: finalTrack?.genre ?? track.genre,
                        releaseYear: finalTrack?.releaseYear ?? track.releaseYear
                    )
                }
            }
            
            guard let track = finalTrack else {
                print("Failed to extract any metadata for \(url.path)")
                throw NSError(domain: "MetadataExtractor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract metadata"])
            }
            
            // If we have TagLib data, use it for the title, artist, and album
            if let tagLibTrack = try? TagLibWrapper.extractMetadata(from: url) {
                if let title = tagLibTrack["title"] as? String, !title.isEmpty {
                    track.title = title
                }
                if let artist = tagLibTrack["artist"] as? String, !artist.isEmpty {
                    track.artist = artist
                }
                if let album = tagLibTrack["album"] as? String, !album.isEmpty {
                    track.album = album
                }
                if let trackNumber = tagLibTrack["track number"] as? Int, trackNumber > 0 {
                    track.trackNumber = trackNumber
                }
            }
            
            // Cache the result
            await cache.set(track, for: url.path)
            return track
        }
    }
    
    private static func loadMetadataValues(from items: [AVMetadataItem]) async throws -> [String: Any] {
        var result: [String: Any] = [:]
        
        try await withThrowingTaskGroup(of: (String, Any?).self) { group in
            for item in items {
                guard let commonKey = item.commonKey?.rawValue else { continue }
                group.addTask {
                    do {
                        let value = try await item.load(.value)
                        return (commonKey, value)
                    } catch {
                        print("Failed to load metadata value for key \(commonKey): \(error)")
                        return (commonKey, nil)
                    }
                }
            }
            for try await (key, value) in group {
                if let value = value {
                    result[key] = value
                }
            }
        }
        return result
    }
    
    /// Helper to produce a "mm:ss" string from track duration
    private static func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds > 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainderSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainderSeconds)
    }
    
    // Where parseTrackNumber could handle string or int values:
    private static func parseTrackNumber(from item: AVMetadataItem) async throws -> Int {
        // If it's directly an Int
        if let val = try await item.load(.value) as? Int {
            return val
        }
        // If it's a string
        if let str = try await item.load(.stringValue) {
            // Handle "01", "1", or "1/12"
            let parts = str.split(separator: "/")
            if let firstPart = parts.first, let val = Int(firstPart) {
                return val
            }
        }
        return -1
    }
    
    /// Parse disc number from metadata
    private static func parseDiscNumber(from item: AVMetadataItem) async throws -> Int {
        if let val = try await item.load(.value) as? Int {
            return val
        }
        if let str = try await item.load(.stringValue) {
            let parts = str.split(separator: "/")
            if let firstPart = parts.first, let val = Int(firstPart) {
                return val
            }
        }
        return -1
    }
}
